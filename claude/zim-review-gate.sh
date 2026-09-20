#!/bin/bash
# Decides whether the branch of a worktree needs a style review, and prints the
# material to review. Prints a SKIP line when no review is due.
#
# Usage: zim-review-gate.sh <cwd> <stop_hook_active> [mode] [argument]
#
# --force reviews the branch even when a stop hook continues the turn, when the
# tree is dirty, or when the review already ran for this HEAD. It still records
# the reviewed sha, so the automatic review does not repeat it.
#
# --record-pass records that the style review of the current HEAD found nothing.
# --check-pass prints PASSED when that record matches the current HEAD, and the
# reason why it does not otherwise. A deep review needs PASSED: it reads the
# type of each commit, and only the style review checks that the type fits the
# diff.
#
# --reviewed-head prints the last HEAD that a style review covered, whatever it
# found. A push gate reads it.
#
# --brief prints the facts of a deep review: the base, each commit with its
# size and its pure-refactor verdict, and the rule files. It spends nothing.
#
# --approve-review "<targets>" records that the user approved a deep review of
# the current HEAD. zim-audit-guard.sh consumes that record: one approval, one
# review. --check-review-approval reports whether such a record matches HEAD.

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

zim_commit_patches() {
  # $1: git directory, $2: a range. Prints each commit with its message and
  # its patch, oldest first. An opaque file shows its stat line only: a
  # recording or a lockfile would fill the cap and blind the review.
  local dir="$1" range="$2" sha opaque
  git -C "$dir" rev-list --reverse --no-merges "$range" |
    while IFS= read -r sha; do
      echo
      echo "### COMMIT $sha"
      git -C "$dir" log -1 --format=%B "$sha"
      echo "--- diff ---"
      opaque=$(zim_opaque_files "$dir" "$sha^!")
      if [ -n "$opaque" ]; then
        echo "opaque files, stat only:"
        printf '%s\n' "$opaque" | while IFS= read -r file; do
          git -C "$dir" diff --numstat "$sha^!" -- "$file" |
            awk -F'\t' '{ if ($1 == "-") print "  " $3 " | binary"
                          else print "  " $3 " | +" $1 " -" $2 }'
        done
      fi
      git -C "$dir" diff --patch "$sha^!" -- . "${ZIM_OPAQUE_EXCLUDE[@]}"
    done
}

[ "$force" = false ] && [ "$stop_hook_active" = "true" ] &&
  skip "a stop hook already continues this turn"

git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  skip "$cwd is not a git worktree"

toplevel=$(git -C "$cwd" rev-parse --show-toplevel)
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD)
head=$(git -C "$cwd" rev-parse HEAD)

mkdir -p "$state_dir"
key=$(zim_state_key "$cwd")
state_file="$state_dir/$key"
pass_file="$state_dir/$key.passed"
approval_file="$state_dir/$key.review-approved"
diff_file="$state_dir/$key.diff"

case "$mode" in
  --record-pass)
    printf '%s\n' "$head" > "$pass_file"
    echo "RECORDED: the style review of $head found nothing."
    exit 0 ;;
  --reviewed-head)
    cat "$state_file" 2>/dev/null
    exit 0 ;;
  --approve-review)
    printf '%s\t%s\n' "$head" "${4:-the branch}" > "$approval_file"
    echo "APPROVED: a deep review of ${4:-the branch} at $head."
    exit 0 ;;
  --check-review-approval)
    if [ ! -f "$approval_file" ]; then
      echo "NOT APPROVED: the user approved no deep review of this worktree."
    elif [ "$(cut -f1 "$approval_file")" != "$head" ]; then
      echo "NOT APPROVED: the approval on file is for $(cut -f1 "$approval_file"), and HEAD is $head."
    else
      echo "APPROVED: $(cut -f2 "$approval_file") at $head."
    fi
    exit 0 ;;
  --check-pass)
    if [ ! -f "$pass_file" ]; then
      echo "NOT PASSED: no style review of $branch ever passed."
    elif [ "$(cat "$pass_file")" != "$head" ]; then
      echo "NOT PASSED: the last passing style review was for $(cat "$pass_file"), and HEAD is $head."
    else
      echo "PASSED: the style review of $head found nothing."
    fi
    exit 0 ;;
esac

if [ "$mode" = "--brief" ]; then
  # The merge request's target is the range the reviewers see; the base finder
  # answers when no merge request exists.
  if base=$(zim_mr_target "$cwd"); then
    base_source="the target branch of the merge request"
  else
    IFS=$'\t' read -r base base_source <<< "$(zim_review_base "$cwd")"
  fi
  git -C "$cwd" rev-parse --verify --quiet "$base" >/dev/null ||
    skip "the base $base does not exist"
  count=$(git -C "$cwd" rev-list --count --no-merges "$base..HEAD")
  [ "$count" -eq 0 ] && skip "$branch adds no non-merge commit above $base"
  echo "BRIEF"
  echo "worktree: $toplevel"
  echo "branch: $branch"
  echo "base: $base ($base_source)"
  echo "range: $base..HEAD"
  echo "style review: $("${BASH_SOURCE[0]}" "$cwd" false --check-pass)"
  echo "behaviour files: $(zim_behaviour_files "$cwd" "$base...HEAD" | wc -l)"
  echo "behaviour lines: $(zim_behaviour_lines "$cwd" "$base...HEAD")"
  echo "opaque files touched: $(zim_opaque_files "$cwd" "$base...HEAD" | wc -l)"
  echo
  echo "=== COMMITS, OLDEST FIRST ==="
  git -C "$cwd" log --reverse --no-merges --format='%h%x09%s' "$base..HEAD" |
    while IFS=$'\t' read -r sha subject; do
      stat=$(git -C "$cwd" show --stat --format= "$sha" | tail -1 | sed 's/^ *//')
      if zim_is_pure_refactor "$cwd" "$sha"; then
        verdict="pure refactor, no deep review"
      else
        verdict="to review"
      fi
      echo "$sha  $subject"
      echo "  $stat"
      echo "  $verdict"
    done
  echo
  echo "=== THE RULE FILES ==="
  for file in "${ZIM_DEEP_REVIEW_RULES[@]}"; do
    [ -f "$toplevel/$file" ] && echo "$toplevel/$file"
  done
  exit 0
fi

IFS=$'\t' read -r base base_source <<< "$(zim_review_base "$cwd")"
git -C "$cwd" rev-parse --verify --quiet "$base" >/dev/null ||
  skip "the base $base does not exist"

count=$(git -C "$cwd" rev-list --count --no-merges "$base..HEAD")
[ "$count" -eq 0 ] && skip "$branch adds no non-merge commit above $base"

[ "$force" = false ] &&
  git -C "$cwd" status --porcelain --untracked-files=no | grep -q . &&
  skip "the tracked tree of $branch is not clean"

[ "$force" = false ] && [ -f "$state_file" ] &&
  [ "$(cat "$state_file")" = "$head" ] &&
  skip "the review already ran for $head"

printf '%s\n' "$head" > "$state_file"

# The rule files open the diff file, so the payload stays under the output cap
# of one tool call whatever their length; the reviewer reads the file anyway.
{
  echo "=== THE RULES ==="
  while IFS= read -r file; do
    echo "--- $(realpath --relative-to="$toplevel" "$file") ---"
    cat "$file"
    echo
  done < <(zim_rule_files "$cwd")
  echo "=== THE COMMITS AND THEIR DIFFS, OLDEST FIRST ==="
  zim_commit_patches "$cwd" "$base..HEAD" | head -n "$max_diff_lines"
} > "$diff_file"
diff_lines=$(wc -l < "$diff_file")
total_lines=$(zim_commit_patches "$cwd" "$base..HEAD" | wc -l)

payload=$(
  echo "REVIEW"
  echo "diff file: $diff_file"
  echo "diff file lines: $diff_lines"
  [ "$total_lines" -gt "$max_diff_lines" ] &&
    echo "diff file truncated: the branch prints $total_lines lines."
  echo "worktree: $toplevel"
  echo "branch: $branch"
  echo "base: $base ($base_source)"
  echo "commits: $count"
  echo "gate: $(cd "$toplevel" && realpath --relative-to="$toplevel" "${BASH_SOURCE[0]}")"
  echo

  echo "=== THE PROCEDURE ==="
  cat "$(dirname "${BASH_SOURCE[0]}")/zim-review-agent.md"
  echo

  echo "=== COMMITS, OLDEST FIRST ==="
  git -C "$cwd" log --reverse --no-merges --format='%H%x09%s' "$base..HEAD" |
    while IFS=$'\t' read -r sha subject; do
      lines=$(zim_production_lines "$cwd" "$sha^!")
      violations=$(zim_diff_violations "$cwd" \
        "$(git -C "$cwd" log -1 --format='%B' "$sha")" \
        "$(git -C "$cwd" log -1 --format='%as' "$sha")" "$sha^!")
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
)

printf '%s\n' "$payload" | head -c "$max_stdout_bytes"
[ "$(printf '%s\n' "$payload" | wc -c)" -gt "$max_stdout_bytes" ] &&
  printf '\nTRUNCATED: the gate kept %s bytes. The diff file holds the diffs.\n' \
    "$max_stdout_bytes"

exit 0
