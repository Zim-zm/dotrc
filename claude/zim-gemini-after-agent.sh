#!/bin/bash
# AfterAgent hook for the Gemini CLI: the counterpart of the Claude Stop hook.
# It runs the gate, and when a review is due it runs the reviewer headless on
# the Flash model, with the diff file on stdin so the reviewer reads no file.
# A pass is recorded here, because the headless reviewer has no shell. A
# finding comes back to the agent as a denial, which is what the Claude hook
# does: the agent reports it, and fixes nothing unless the user asks.

set -u

# The nested reviewer loads this hook too; its own gate would skip on the
# recorded HEAD, but the child answers nothing and exits before that.
[ -n "${ZIM_REVIEW_CHILD:-}" ] && exit 0

model=gemini-2.5-flash
gate="$(dirname "${BASH_SOURCE[0]}")/zim-review-gate.sh"

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
stop_hook_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false')

command -v gemini >/dev/null || exit 0

payload=$("$gate" "$cwd" "$stop_hook_active")
case "$payload" in SKIP:*) exit 0 ;; esac

diff_file=$(printf '%s\n' "$payload" | sed -n 's/^diff file: //p' | head -1)
[ -f "$diff_file" ] || exit 0

preface="You are the reviewer of the procedure below. The diff file that the header
names is the text that precedes this prompt on your input, in full: read it
there, and open no file. You have no shell, so do not run the gate: the
launcher records a pass from your answer. Answer with the JSON the procedure
describes and nothing else."

response=$(cd "$cwd" && ZIM_REVIEW_CHILD=1 gemini -m "$model" --output-format json \
  -p "$preface

$payload" < "$diff_file" 2>/dev/null | jq -r '.response // empty')

answer=$(printf '%s' "$response" | perl -0777 -ne 'print $1 if /(\{\s*"ok"\s*:.*\})/s')
ok=$(printf '%s' "$answer" | jq -r 'if has("ok") then (.ok | tostring) else empty end' 2>/dev/null)

case "$ok" in
  true)
    "$gate" "$cwd" false --record-pass >/dev/null
    notes=$(printf '%s' "$answer" | jq -r '.notes // empty')
    [ -n "$notes" ] &&
      jq -n --arg m "The style review recorded a pass. These notes block nothing; the user decides.

$notes" '{systemMessage: $m}'
    exit 0 ;;
  false)
    reason=$(printf '%s' "$answer" | jq -r '.reason // empty')
    jq -n --arg r "The commit style review of the branch found these problems. Report them to the user as they are, grouped by commit. Fix nothing unless the user asks.

$reason" '{decision: "deny", reason: $r}'
    exit 0 ;;
  *)
    jq -n --arg m "The style review gave no verdict: the reviewer answered without the JSON the procedure asks for. Run it again with /check-style." \
      '{systemMessage: $m}'
    exit 0 ;;
esac
