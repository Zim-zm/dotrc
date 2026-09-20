#!/bin/bash
# Installs the commit-style review setup into one worktree of a project.
# Run it again after a pull: every step is idempotent.
#
#   ./install.sh --project <name|dir> --tracked <worktree>
#       vendors the mechanism and the project's policy into the worktree, for
#       you to commit: they then propagate by merge.
#   ./install.sh --project <name|dir> --local <worktree>
#       the same files at the same paths, kept out of git: each path goes into
#       the clone's info/exclude, and the hooks register in
#       .claude/settings.local.json.
#   ./install.sh --with-statusline
#       also the status line, in the user's own settings.
#
# <name> is a directory of projects/; <dir> is any directory that holds a
# policy.sh and the project's rule files.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
vendor=hooks/commit
mechanism="zim-paths.sh zim-rules.sh zim-commit-guard.sh zim-review-gate.sh
  zim-review-agent.md zim-audit-guard.sh zim-stop-hook-prompt.txt
  zim-gemini-after-agent.sh"

project=""
mode=""
worktree=""
with_statusline=false
while [ $# -gt 0 ]; do
  case "$1" in
    --project) project="$2"; shift 2 ;;
    --tracked|--local) mode="${1#--}"; worktree="$2"; shift 2 ;;
    --with-statusline) with_statusline=true; shift ;;
    *) echo "$1 is not an option of this installer." >&2; exit 1 ;;
  esac
done

for tool in git jq perl awk sha1sum realpath; do
  command -v "$tool" >/dev/null ||
    { echo "$tool is missing, and the setup needs it." >&2; exit 1; }
done

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
edit() { # $1: the settings file, the rest: jq arguments
  local file="$1"; shift
  [ -f "$file" ] || echo '{}' > "$file"
  jq "$@" "$file" > "$tmp" && cp "$tmp" "$file"
}

if [ "$with_statusline" = true ]; then
  edit "$claude_dir/settings.json" --arg cmd "$here/sta-line.sh" \
    '.statusLine = {type: "command", command: $cmd}'
  echo "installed the status line in $claude_dir/settings.json"
fi

[ -n "$project" ] || { [ "$with_statusline" = true ] && exit 0
  echo "Name the project: --project <name|dir> --tracked|--local <worktree>." >&2; exit 1; }
[ -n "$mode" ] ||
  { echo "Choose --tracked <worktree> or --local <worktree>." >&2; exit 1; }

if [ -d "$here/projects/$project" ]; then
  policy_dir="$here/projects/$project"
elif [ -d "$project" ]; then
  policy_dir=$(cd "$project" && pwd)
else
  echo "$project is neither a directory of projects/ nor a directory." >&2; exit 1
fi
[ -f "$policy_dir/policy.sh" ] ||
  { echo "$policy_dir holds no policy.sh." >&2; exit 1; }

top=$(git -C "$worktree" rev-parse --show-toplevel 2>/dev/null) ||
  { echo "$worktree is not inside a git worktree." >&2; exit 1; }
common=$(git -C "$top" rev-parse --git-common-dir)
case "$common" in /*) ;; *) common="$top/$common" ;; esac

# The policy names the skills and the rule files.
source "$policy_dir/policy.sh"

installed=()
skipped=()
put() { # $1: source file or directory, $2: path relative to the worktree
  # Local mode keeps out of git, so it leaves a path that git tracks: the
  # exclude list cannot hide a tracked file, and a change to it would be a
  # change of the branch.
  if [ "$mode" = local ] &&
     git -C "$top" ls-files --error-unmatch "$2" >/dev/null 2>&1; then
    skipped+=("$2")
    return
  fi
  mkdir -p "$(dirname "$top/$2")"
  if [ -d "$1" ]; then
    rm -rf "${top:?}/${2:?}"
    cp -r "$1" "$top/$2"
  else
    cp "$1" "$top/$2"
  fi
  installed+=("$2")
}

for file in $mechanism; do put "$here/$file" "$vendor/$file"; done
put "$policy_dir/policy.sh" "$vendor/policy.sh"
{
  echo "source: $(git -C "$here" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "policy: $(basename "$policy_dir")"
  echo "mode: $mode"
  echo "date: $(date +%F)"
} > "$top/$vendor/SOURCE"
installed+=("$vendor/SOURCE")
chmod +x "$top/$vendor"/*.sh

put "$here/RULES.md" RULES.md
for file in "$policy_dir"/*; do
  [ "$(basename "$file")" = policy.sh ] && continue
  put "$file" "$(basename "$file")"
done
for skill in $ZIM_SKILLS; do
  [ -d "$here/skills/$skill" ] ||
    { echo "the policy names the skill $skill, and skills/$skill does not exist." >&2; exit 1; }
  put "$here/skills/$skill" ".claude/skills/$skill"
done

case "$mode" in
  tracked) settings="$top/.claude/settings.json" ;;
  local) settings="$top/.claude/settings.local.json" ;;
esac
mkdir -p "$top/.claude"

add_command_hook() { # $1 event, $2 matcher, $3 command, $4 timeout
  edit "$settings" --arg ev "$1" --arg m "$2" --arg cmd "$3" --argjson t "$4" '
    .hooks //= {} | .hooks[$ev] //= []
    | if any(.hooks[$ev][]; any(.hooks[]?; .command == $cmd)) then .
      else .hooks[$ev] += [{matcher: $m,
             hooks: [{type: "command", command: $cmd, timeout: $t}]}] end'
}
add_command_hook PreToolUse Bash "\"\$CLAUDE_PROJECT_DIR\"/$vendor/zim-commit-guard.sh" 30
add_command_hook PreToolUse 'Agent|Task' "\"\$CLAUDE_PROJECT_DIR\"/$vendor/zim-audit-guard.sh" 10
edit "$settings" --arg prompt "$(cat "$here/zim-stop-hook-prompt.txt")" '
  .hooks //= {} | .hooks.Stop //= []
  | if any(.hooks.Stop[]; any(.hooks[]?; .type == "agent"
      and (.prompt | test("zim-review-gate")))) then .
    else .hooks.Stop += [{hooks: [{type: "agent", prompt: $prompt,
           model: "claude-sonnet-5", timeout: 300}]}] end'
edit "$settings" --arg gate "Bash($vendor/zim-review-gate.sh:*)" '
  .permissions.allow //= []
  | .permissions.allow |= (. + [$gate, "Read(~/.claude/zim-review-state/**)"] | unique)'
installed+=("${settings#"$top"/}")

# The Gemini CLI reads one project settings file and knows no local variant,
# so local mode registers its hook only when the branch does not track the
# file.
gemini_settings="$top/.gemini/settings.json"
if [ "$mode" = local ] &&
   git -C "$top" ls-files --error-unmatch .gemini/settings.json >/dev/null 2>&1; then
  skipped+=(.gemini/settings.json)
else
  mkdir -p "$top/.gemini"
  edit "$gemini_settings" --arg cmd "./$vendor/zim-gemini-after-agent.sh" '
    .hooks //= {} | .hooks.AfterAgent //= []
    | if any(.hooks.AfterAgent[]; any(.hooks[]?; .command == $cmd)) then .
      else .hooks.AfterAgent += [{hooks: [{type: "command", command: $cmd,
             name: "Commit style review", timeout: 300000}]}] end'
  installed+=(.gemini/settings.json)
fi

echo "installed into $top, in $mode mode:"
printf '  %s\n' "${installed[@]}"
if [ ${#skipped[@]} -gt 0 ]; then
  echo "left alone, because the branch tracks them and local mode changes no branch:"
  printf '  %s\n' "${skipped[@]}"
fi

if [ "$mode" = local ]; then
  exclude="$common/info/exclude"
  mkdir -p "$(dirname "$exclude")"
  touch "$exclude"
  for path in "${installed[@]}"; do
    grep -qxF "/$path" "$exclude" || echo "/$path" >> "$exclude"
  done
  echo "excluded every path in $exclude, which every worktree of the clone shares"
  cat <<'NOTE'

Local mode installs no git hook: a tracked commit-msg hook cannot source an
untracked library, so the mechanical refusal comes from the Claude guard alone,
and a commit made outside Claude gets no check. If a branch later tracks a file
at one of these paths, git checkout refuses to overwrite the local copy: remove
the local copy before you switch.
NOTE
fi

if [ "$mode" = tracked ]; then
  cat <<NOTE

Commit these paths. The project's own commit-msg hook gives the same verdict to
every tool when it sources $vendor/zim-rules.sh and calls
zim_diff_violations; see README.md.
NOTE
fi
