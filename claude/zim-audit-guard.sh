#!/bin/bash
# PreToolUse guard on the Agent tool. A deep audit costs minutes and millions of
# tokens, so the user approves each one. The zim-audit skill records the
# approval with zim-review-gate.sh --approve-audit; this guard consumes it, so
# one approval buys one audit.

set -u

source "$(dirname "${BASH_SOURCE[0]}")/zim-paths.sh"

input=$(cat)
prompt=$(printf '%s' "$input" | jq -r '.tool_input.prompt // ""')
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')

printf '%s' "$prompt" | head -1 | grep -q '^ZIM-AUDIT' || exit 0

key=$(zim_state_key "$cwd")
[ -n "$key" ] || exit 0

approval_file="$ZIM_STATE_DIR/$key.audit-approved"
head=$(git -C "$cwd" rev-parse HEAD 2>/dev/null)

if [ ! -f "$approval_file" ] || [ "$(cut -f1 "$approval_file")" != "$head" ]; then
  {
    echo "A deep audit needs an explicit approval from the user."
    echo "Report what the audit would cover, ask whether to run it or to skip it,"
    echo "and record the answer before you spawn the agent:"
    echo "  $(dirname "${BASH_SOURCE[0]}")/zim-review-gate.sh \"$cwd\" false --approve-audit \"<the commits>\""
  } >&2
  exit 2
fi

rm -f "$approval_file"
exit 0
