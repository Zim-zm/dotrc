#!/bin/bash
# Decides whether the branch of a worktree needs a style review, and prints the
# material to review. Prints a SKIP line when no review is due.
#
# Usage: zim-review-gate.sh <cwd> <stop_hook_active> [--force|--record-pass|--check-pass]
#
# --force reviews the branch even when a stop hook continues the turn, when the
# tree is dirty, or when the review already ran for this HEAD. It still records
# the reviewed sha, so the automatic review does not repeat it.
#
# --approve-audit "<targets>" records that the user approved a deep audit of the
# current HEAD. zim-audit-guard.sh consumes that record: one approval, one audit.
# --check-audit-approval reports whether such a record matches the current HEAD.
#
# --record-pass records that the style review of the current HEAD found nothing.
# --check-pass prints PASSED when that record matches the current HEAD, and the
# reason why it does not otherwise. A deep audit needs PASSED: it reads the type
# of each commit, and only the style review checks that the type fits the diff.

set -u

source "$(dirname "${BASH_SOURCE[0]}")/zim-paths.sh"
source "$(dirname "${BASH_SOURCE[0]}")/zim-rules.sh"

cwd="${1:-$PWD}"
stop_hook_active="${2:-false}"
mode="${3:-}"
force=false
[ "$mode" = "--force" ] && force=true
state_dir="$ZIM_STATE_DIR"
max_diff_lines=6000
max_stdout_bytes=24000

skip() { echo "SKIP: $1"; exit 0; }

[ "$force" = false ] && [ "$stop_hook_active" = "true" ] &&
  skip "a stop hook already continues this turn"

git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  skip "$cwd is not a git worktree"

toplevel=$(git -C "$cwd" rev-parse --show-toplevel)
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD)
base=$(git -C "$cwd" config zim.reviewBase || echo origin/master)

git -C "$cwd" rev-parse --verify --quiet "$base" >/dev/null ||
  skip "the base $base does not exist"

head=$(git -C "$cwd" rev-parse HEAD)

mkdir -p "$state_dir"
key=$(zim_state_key "$cwd")
state_file="$state_dir/$key"
pass_file="$state_dir/$key.passed"
approval_file="$state_dir/$key.audit-approved"
diff_file="$state_dir/$key.diff"

if [ "$mode" = "--record-pass" ]; then
  printf '%s\n' "$head" > "$pass_file"
  echo "RECORDED: the style review of $head found nothing."
  exit 0
fi

if [ "$mode" = "--approve-audit" ]; then
  printf '%s\t%s\n' "$head" "${4:-the branch}" > "$approval_file"
  echo "APPROVED: a deep audit of ${4:-the branch} at $head."
  exit 0
fi

if [ "$mode" = "--check-audit-approval" ]; then
  if [ ! -f "$approval_file" ]; then
    echo "NOT APPROVED: the user approved no audit of this worktree."
  elif [ "$(cut -f1 "$approval_file")" != "$head" ]; then
    echo "NOT APPROVED: the approval on file is for $(cut -f1 "$approval_file"), and HEAD is $head."
  else
    echo "APPROVED: $(cut -f2 "$approval_file") at $head."
  fi
  exit 0
fi

if [ "$mode" = "--check-pass" ]; then
  if [ ! -f "$pass_file" ]; then
    echo "NOT PASSED: no style review of $branch ever passed."
  elif [ "$(cat "$pass_file")" != "$head" ]; then
    echo "NOT PASSED: the last passing style review was for $(cat "$pass_file"), and HEAD is $head."
  else
    echo "PASSED: the style review of $head found nothing."
  fi
  exit 0
fi

count=$(git -C "$cwd" rev-list --count --no-merges "$base..HEAD")
[ "$count" -eq 0 ] && skip "$branch adds no non-merge commit above $base"

[ "$force" = false ] &&
  git -C "$cwd" status --porcelain --untracked-files=no | grep -q . &&
  skip "the tracked tree of $branch is not clean"

[ "$force" = false ] && [ -f "$state_file" ] &&
  [ "$(cat "$state_file")" = "$head" ] &&
  skip "the review already ran for $head"

printf '%s\n' "$head" > "$state_file"

git -C "$cwd" log --reverse --no-merges --patch \
  --format='%n### COMMIT %H%n%B%n--- diff ---' "$base..HEAD" |
  head -n "$max_diff_lines" > "$diff_file"
diff_lines=$(wc -l < "$diff_file")
total_lines=$(git -C "$cwd" log --reverse --no-merges --patch "$base..HEAD" | wc -l)

payload=$(
  echo "REVIEW"
  echo "worktree: $toplevel"
  echo "branch: $branch"
  echo "base: $base"
  echo "commits: $count"
  echo "diff file: $diff_file"
  echo "diff file lines: $diff_lines"
  [ "$total_lines" -gt "$max_diff_lines" ] &&
    echo "diff file truncated: the branch prints $total_lines lines."
  echo

  echo "=== THE PROCEDURE ==="
  cat "$(dirname "${BASH_SOURCE[0]}")/zim-review-agent.md"
  echo

  echo "=== COMMITS, OLDEST FIRST ==="
  git -C "$cwd" log --reverse --no-merges --format='%H%x09%s' "$base..HEAD" |
    while IFS=$'\t' read -r sha subject; do
      lines=$(zim_production_lines "$cwd" "$sha^!")
      violations=$(zim_message_violations \
        "$(git -C "$cwd" log -1 --format='%B' "$sha")" "$lines" \
        "$(git -C "$cwd" log -1 --format='%as' "$sha")")
      echo "$sha  production_lines=$lines  $subject"
      if [ -z "$violations" ]; then
        echo "  mechanical: OK"
      else
        printf '%s\n' "$violations" | sed 's|^|  mechanical: |'
      fi
    done
  echo

  echo "=== THE COMMIT TYPES ==="
  zim_commit_type_table
  echo

  echo "=== THE RULES ==="
  cat "$HOME/.claude/skills/zim-code/SKILL.md"
  echo
)

printf '%s\n' "$payload" | head -c "$max_stdout_bytes"
[ "$(printf '%s\n' "$payload" | wc -c)" -gt "$max_stdout_bytes" ] &&
  printf '\nTRUNCATED: the gate kept %s bytes. The diff file holds the diffs.\n' \
    "$max_stdout_bytes"

exit 0
