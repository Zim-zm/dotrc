# The state directory of the review system, the diff helpers that read the
# policy's pathspecs, the comment syntax of each extension, and the base that a
# review covers. Sourced by zim-review-gate.sh, zim-commit-guard.sh and
# zim-audit-guard.sh: one source of truth.
#
# The policy of the project sits next to this file as policy.sh. The installer
# copies it there from projects/<name>/policy.sh.

zim_here=$(dirname "${BASH_SOURCE[0]}")
if [ ! -f "$zim_here/policy.sh" ]; then
  echo "zim: $zim_here/policy.sh is missing. Run install.sh --project <policy dir>." >&2
  return 1 2>/dev/null || exit 1
fi
source "$zim_here/policy.sh"
unset zim_here

ZIM_STATE_DIR="$HOME/.claude/zim-review-state"

zim_state_key() {
  # $1: a directory inside a worktree. One key per worktree.
  printf '%s' "$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" |
    sha1sum | cut -c1-16
}

# The non-production pathspecs, as a positive pathspec: what a production
# change must not touch.
ZIM_NON_PRODUCTION_PATHS=()
for zim_p in "${ZIM_NON_PRODUCTION[@]}"; do
  ZIM_NON_PRODUCTION_PATHS+=("${zim_p#:!}")
done
unset zim_p

zim_non_production_files() {
  # $1: git directory, remaining arguments: a diff range or --cached.
  local dir="$1"; shift
  git -C "$dir" diff --name-only "$@" -- "${ZIM_NON_PRODUCTION_PATHS[@]}" 2>/dev/null
}

zim_recorded_output_files() {
  # $1: git directory, remaining arguments: a diff range or --cached. Prints the
  # changed files that record a result of the program.
  local dir="$1"; shift
  git -C "$dir" diff --name-only "$@" -- "${ZIM_RECORDED_OUTPUT[@]}" 2>/dev/null
}

zim_production_lines() {
  # $1: git directory, remaining arguments: a diff range or --cached.
  local dir="$1"; shift
  git -C "$dir" diff --numstat "$@" -- . "${ZIM_NON_PRODUCTION[@]}" 2>/dev/null |
    awk '$1 != "-" { added += $1; removed += $2 } END { print added + removed + 0 }'
}

zim_comment_markers() {
  # $1: a path. Prints the line marker, the block opener and the block closer of
  # the language, separated by "|". Prints nothing for an extension that this
  # table does not name.
  case "$1" in
    *.c|*.h|*.cpp|*.cxx|*.cc|*.hpp|*.hh|*.rs|*.js|*.mjs|*.ts|*.java|*.css|*.svelte)
      printf '%s' '//|/*|*/' ;;
    *.ml|*.mli|*.mly|*.mll)
      printf '%s' '|(*|*)' ;;
    *.sh|*.bash|*.py|*.pl|*.rb|*.yml|*.yaml|*.toml|*.ini|*.cfg|*.mk|*.opam|Makefile|*/Makefile)
      printf '%s' '#||' ;;
    *.lua|*.sql|*.hs|*.adb|*.ads)
      printf '%s' '--||' ;;
    *.vim)
      printf '%s' '"||' ;;
    dune|*/dune|dune-project|*/dune-project|*.el|*.lisp|*.scm)
      printf '%s' ';||' ;;
  esac
}

zim_production_code_lines() {
  # $1: git directory, remaining arguments: a diff range or --cached. Counts the
  # changed production lines that are neither blank nor a comment. A file whose
  # extension zim_comment_markers does not name keeps every changed line.
  local dir="$1"; shift
  local file markers line_marker opener closer count total=0
  while IFS= read -r file; do
    markers=$(zim_comment_markers "$file")
    if [ -z "$markers" ]; then
      count=$(git -C "$dir" diff --numstat "$@" -- "$file" 2>/dev/null |
        awk '$1 != "-" { added += $1; removed += $2 } END { print added + removed + 0 }')
    else
      IFS='|' read -r line_marker opener closer <<<"$markers"
      count=$(git -C "$dir" diff -U0 "$@" -- "$file" 2>/dev/null |
        awk -v line="$line_marker" -v opener="$opener" -v closer="$closer" '
          function is_comment(text) {
            sub(/^[[:space:]]+/, "", text)
            sub(/[[:space:]]+$/, "", text)
            if (text == "") return 1
            if (line != "" && index(text, line) == 1) return 1
            if (opener == "") return 0
            if (index(text, opener) == 1 || index(text, closer) == 1) return 1
            if (substr(text, length(text) - length(closer) + 1) == closer) return 1
            return (text == "*" || index(text, "* ") == 1)
          }
          /^(\+\+\+|---)/ { next }
          /^[-+]/ { if (!is_comment(substr($0, 2))) code++ }
          END { print code + 0 }')
    fi
    total=$((total + count))
  done < <(git -C "$dir" diff --name-only "$@" -- . "${ZIM_NON_PRODUCTION[@]}" 2>/dev/null)
  printf '%s' "$total"
}

zim_rule_files() {
  # $1: a directory inside a worktree. Prints the absolute path of each rule
  # file of the policy that exists in the worktree, in the policy's order.
  local top file
  top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 0
  for file in "${ZIM_RULE_FILES[@]}"; do
    [ -f "$top/$file" ] && printf '%s\n' "$top/$file"
  done
  return 0
}

zim_mr_target() {
  # $1: a directory inside a worktree. Prints the target branch of the merge
  # request of the current branch, as origin/<branch>, when glab can name one.
  local dir="$1" target
  command -v glab >/dev/null || return 1
  target=$(cd "$dir" && glab mr view --output json 2>/dev/null |
    jq -r '.target_branch // empty' 2>/dev/null)
  [ -n "$target" ] || return 1
  git -C "$dir" rev-parse --verify --quiet "origin/$target" >/dev/null || return 1
  printf 'origin/%s' "$target"
}

ZIM_BASE_CANDIDATES=(origin/main origin/master origin/develop)
ZIM_BASE_WALK_MAX=1000

zim_review_base() {
  # $1: a directory inside a worktree. Prints the base to review against, a tab,
  # then where it comes from.
  local dir="$1" branch configured ref count default_ref count_label
  local integration best best_count limit nearest
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)

  configured=$(git -C "$dir" config "zim.$branch.reviewBase" 2>/dev/null) &&
    { printf '%s\t%s' "$configured" "the zim.$branch.reviewBase config"; return; }
  configured=$(git -C "$dir" config zim.reviewBase 2>/dev/null) &&
    { printf '%s\t%s' "$configured" "the zim.reviewBase config"; return; }

  default_ref=$(git -C "$dir" rev-parse --abbrev-ref origin/HEAD 2>/dev/null)
  [ "$default_ref" = "origin/HEAD" ] && default_ref=""

  # An integration branch moves on its own, so it is no longer an ancestor of
  # HEAD. A shared merge-base keeps it a candidate.
  integration=$( { [ -n "$default_ref" ] && printf '%s\n' "$default_ref"
                   printf '%s\n' "$ZIM_BASE_DEFAULT" "${ZIM_BASE_CANDIDATES[@]}"; } |
                 awk '!seen[$0]++')
  best=""; best_count=""
  while IFS= read -r ref; do
    [ -n "$ref" ] && [ "$ref" != "$branch" ] || continue
    git -C "$dir" rev-parse --verify --quiet "$ref" >/dev/null || continue
    git -C "$dir" merge-base "$ref" HEAD >/dev/null 2>&1 || continue
    count=$(git -C "$dir" rev-list --count --no-merges "$ref..HEAD" 2>/dev/null)
    [ "${count:-0}" -gt 0 ] || continue
    best="$ref"; best_count="$count"
    break
  done <<< "$integration"

  # The branch below a stacked branch sits inside the history of HEAD. The walk
  # stops at the count of the integration branch, because a tip that is farther
  # gives a longer review, and because a count for each branch of a large
  # repository costs minutes.
  limit=${best_count:-$ZIM_BASE_WALK_MAX}
  nearest=$(git -C "$dir" log --format='%D' --decorate-refs=refs/heads \
              -n "$limit" HEAD 2>/dev/null |
    awk -v self="$branch" 'NR > 1 && $0 != "" {
      n = split($0, names, ", ")
      for (i = 1; i <= n; i++)
        if (names[i] != self && names[i] != "HEAD") { print names[i]; exit }
    }')
  if [ -n "$nearest" ]; then
    count=$(git -C "$dir" rev-list --count --no-merges "$nearest..HEAD" 2>/dev/null)
    if [ "${count:-0}" -gt 0 ] &&
       { [ -z "$best_count" ] || [ "$count" -lt "$best_count" ]; }; then
      [ "$count" -eq 1 ] && count_label=commit || count_label=commits
      printf '%s\t%s' "$nearest" "the nearest ancestor, $count $count_label below HEAD"
      return
    fi
  fi

  if [ -n "$best" ]; then
    [ "$best_count" -eq 1 ] && count_label=commit || count_label=commits
    printf '%s\t%s' "$best" "the integration branch, $best_count $count_label below HEAD"
    return
  fi
  printf '%s\t%s' "$ZIM_BASE_DEFAULT" "the last-resort default of the policy"
}
