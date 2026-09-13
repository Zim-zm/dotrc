# Pathspecs that exclude non-production files from a diff, the state directory
# of the review system, and the base that a review covers.
# Sourced by zim-review-gate.sh, zim-commit-guard.sh and zim-audit-guard.sh:
# one source of truth.

ZIM_STATE_DIR="$HOME/.claude/zim-review-state"

zim_state_key() {
  # $1: a directory inside a worktree. One key per worktree.
  printf '%s' "$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" |
    sha1sum | cut -c1-16
}

ZIM_NON_PRODUCTION=(
  ':!*/tests/*'
  ':!tests/*'
  ':!*/oracle/*'
  ':!*.oracle'
  ':!*doc/*'
  ':!*.md'
  ':!*.rst'
)

# The same paths, as a positive pathspec: what a production change must not touch.
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

ZIM_RECORDED_OUTPUT=(
  "oracle/*"
  "*/oracle/*"
  "*.oracle"
)

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
    awk '{ added += $1; removed += $2 } END { print added + removed + 0 }'
}

zim_comment_markers() {
  # $1: a path. Prints the line marker, the block opener and the block closer of
  # the language, separated by "|". Prints nothing for an extension that this
  # table does not name.
  case "$1" in
    *.c|*.h|*.cpp|*.cxx|*.cc|*.hpp|*.hh|*.rs|*.js|*.ts|*.java|*.css)
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
        awk '{ added += $1; removed += $2 } END { print added + removed + 0 }')
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

ZIM_BASE_CANDIDATES=(origin/main origin/master origin/develop)

zim_review_base() {
  # $1: a directory inside a worktree. Prints the base to review against, a tab,
  # then where it comes from.
  local dir="$1" branch configured ref pool best best_count count default_ref
  local count_label
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)

  configured=$(git -C "$dir" config "zim.$branch.reviewBase" 2>/dev/null) &&
    { printf '%s\t%s' "$configured" "the zim.$branch.reviewBase config"; return; }
  configured=$(git -C "$dir" config zim.reviewBase 2>/dev/null) &&
    { printf '%s\t%s' "$configured" "the zim.reviewBase config"; return; }

  default_ref=$(git -C "$dir" rev-parse --abbrev-ref origin/HEAD 2>/dev/null)
  [ "$default_ref" = "origin/HEAD" ] && default_ref=""

  best=""; best_count=""
  pool=$( { git -C "$dir" for-each-ref --format='%(refname:short)' refs/heads
            [ -n "$default_ref" ] && printf '%s\n' "$default_ref"
            printf '%s\n' "${ZIM_BASE_CANDIDATES[@]}"; } | sort -u)
  while IFS= read -r ref; do
    [ -n "$ref" ] && [ "$ref" != "$branch" ] || continue
    git -C "$dir" rev-parse --verify --quiet "$ref" >/dev/null || continue
    git -C "$dir" merge-base --is-ancestor "$ref" HEAD 2>/dev/null || continue
    count=$(git -C "$dir" rev-list --count --no-merges "$ref..HEAD" 2>/dev/null)
    [ "${count:-0}" -gt 0 ] || continue
    if [ -z "$best_count" ] || [ "$count" -lt "$best_count" ]; then
      best="$ref"; best_count="$count"
    fi
  done <<< "$pool"

  if [ -n "$best" ]; then
    [ "$best_count" -eq 1 ] && count_label=commit || count_label=commits
    printf '%s\t%s' "$best" "the nearest ancestor, $best_count $count_label below HEAD"
    return
  fi
  printf '%s\t%s' "origin/master" "the last-resort default"
}
