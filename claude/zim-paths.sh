# Pathspecs that exclude non-production files from a diff, and the state
# directory of the review system.
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

zim_production_lines() {
  # $1: git directory, remaining arguments: a diff range or --cached.
  local dir="$1"; shift
  git -C "$dir" diff --numstat "$@" -- . "${ZIM_NON_PRODUCTION[@]}" 2>/dev/null |
    awk '{ added += $1; removed += $2 } END { print added + removed + 0 }'
}
