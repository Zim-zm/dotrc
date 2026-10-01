#!/bin/bash
# PreToolUse guard on the Agent tool. A deep review costs minutes and millions
# of tokens, so the user approves each one. The deep-review skill records the
# approval with zim-review-gate.sh --approve-review; this guard consumes it, so
# one approval buys one review.

set -u

source "$(dirname "${BASH_SOURCE[0]}")/zim-paths.sh"

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.tool_input.prompt // ""')
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')

marker=$(printf '%s' "$prompt" | head -1)
case "$marker" in ZIM-DEEP-REVIEW*) ;; *) exit 0 ;; esac

# The marker names the worktree under review when it is not the session's.
target=$(printf '%s' "$marker" | sed -n 's/^ZIM-DEEP-REVIEW[[:space:]]\{1,\}//p')
case "$target" in
  '') target=$cwd ;;
  /*) ;;
  *) target=$cwd/$target ;;
esac

key=$(zim_state_key "$target")
[ -n "$key" ] || exit 0

approval_file="$ZIM_STATE_DIR/$key.review-approved"
head=$(git -C "$target" rev-parse HEAD 2>/dev/null)

if [ ! -f "$approval_file" ] || [ "$(cut -f1 "$approval_file")" != "$head" ]; then
  {
    echo "A deep review needs an explicit approval from the user."
    echo "Report what the review would cover, ask whether to run it or to skip it,"
    echo "and record the answer before you spawn the agent:"
    echo "  $(dirname "${BASH_SOURCE[0]}")/zim-review-gate.sh \"$target\" false --approve-review \"<the commits>\""
  } >&2
  exit 2
fi

rm -f "$approval_file"
exit 0
