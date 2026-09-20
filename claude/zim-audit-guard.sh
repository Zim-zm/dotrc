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

printf '%s' "$prompt" | head -1 | grep -q '^ZIM-DEEP-REVIEW' || exit 0

key=$(zim_state_key "$cwd")
[ -n "$key" ] || exit 0

approval_file="$ZIM_STATE_DIR/$key.review-approved"
head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null)

if [ ! -f "$approval_file" ] || [ "$(cut -f1 "$approval_file")" != "$head" ]; then
  {
    echo "A deep review needs an explicit approval from the user."
    echo "Report what the review would cover, ask whether to run it or to skip it,"
    echo "and record the answer before you spawn the agent:"
    echo "  $(dirname "${BASH_SOURCE[0]}")/zim-review-gate.sh \"$cwd\" false --approve-review \"<the commits>\""
  } >&2
  exit 2
fi

rm -f "$approval_file"
exit 0
