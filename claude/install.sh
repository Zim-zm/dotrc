#!/bin/bash
# Installs the commit-style review setup of this directory for the current user.
# Run it again after a pull: every step is idempotent.
#
#   ./install.sh                 the guards, the review, the two skills
#   ./install.sh --with-statusline   also the status line

set -eu

here=$(cd "$(dirname "$0")" && pwd)
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$claude_dir/settings.json"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

for tool in git jq perl awk sha1sum; do
  command -v "$tool" >/dev/null ||
    { echo "$tool is missing, and the setup needs it." >&2; exit 1; }
done

mkdir -p "$claude_dir/skills"
ln -sfn "$here" "$claude_dir/zim"
for skill in zim-code zim-review zim-audit; do
  ln -sfn "$here/skills/$skill" "$claude_dir/skills/$skill"
done
echo "linked $claude_dir/zim and the three skills"

[ -f "$settings" ] || echo '{}' > "$settings"
cp "$settings" "$settings.zim-backup"

edit() { jq "$@" "$settings" > "$tmp" && mv "$tmp" "$settings"; }

add_command_hook() { # $1 event, $2 matcher, $3 command, $4 timeout
  edit --arg ev "$1" --arg m "$2" --arg cmd "$3" --argjson t "$4" '
    .hooks //= {} | .hooks[$ev] //= []
    | if any(.hooks[$ev][]; any(.hooks[]?; .command == $cmd)) then .
      else .hooks[$ev] += [{matcher: $m,
             hooks: [{type: "command", command: $cmd, timeout: $t}]}] end'
}

add_command_hook PreToolUse Bash '~/.claude/zim/zim-commit-guard.sh' 30
add_command_hook PreToolUse 'Agent|Task' '~/.claude/zim/zim-audit-guard.sh' 10
echo "registered the commit guard and the audit guard"

edit --arg prompt "$(cat "$here/zim-stop-hook-prompt.txt")" '
  .hooks //= {} | .hooks.Stop //= []
  | if any(.hooks.Stop[]; any(.hooks[]?; .type == "agent"
      and (.prompt | test("zim-review-gate")))) then .
    else .hooks.Stop += [{hooks: [{type: "agent", prompt: $prompt,
           model: "claude-sonnet-5", timeout: 300}]}] end'
echo "registered the style review on Stop, on Sonnet 5"

edit '.permissions.allow //= []
  | .permissions.allow |= (. + ["Bash(~/.claude/zim/zim-review-gate.sh:*)",
      "Read(//" + (env.HOME | ltrimstr("/")) + "/.claude/zim-review-state/**)"]
      | unique)'
echo "allowed the gate and the state directory"

if [ "${1:-}" = "--with-statusline" ]; then
  edit '.statusLine = {type: "command", command: "~/.claude/zim/sta-line.sh"}'
  echo "installed the status line"
fi

cat <<'NEXT'

Installed. The previous settings are in settings.json.zim-backup.

Read README.md, then tune these before your first commit:
  zim-rules.sh   ZIM_COMMIT_TYPES, the type table, the subject and body rules
  zim-paths.sh   ZIM_NON_PRODUCTION, the paths that are not production code
  skills/zim-code/SKILL.md   the written rules that the reviewer reads
NEXT
