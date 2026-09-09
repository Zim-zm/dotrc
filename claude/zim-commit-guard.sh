#!/bin/bash
# PreToolUse guard on Bash. Blocks a `git commit` that breaks a mechanical rule
# of the zim-code style, and injects the rules that need judgment.

set -u

source "$(dirname "${BASH_SOURCE[0]}")/zim-paths.sh"
source "$(dirname "${BASH_SOURCE[0]}")/zim-rules.sh"

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')

# The command position matters: prose inside a heredoc mentions a command
# without running it.
printf '%s' "$command" |
  grep -qE '(^|[;&|(]|&&|\|\|)[[:space:]]*(WIP=1[[:space:]]+)?git[[:space:]]+(-[^ ]+[[:space:]]+)*commit([[:space:]]|$)' ||
  exit 0

[ "$(git -C "$cwd" rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ] || exit 0

case "$cwd" in /tmp/*|*/scratchpad/*) exit 0 ;; esac

git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
[ -f "$git_dir/MERGE_HEAD" ] && exit 0

amend=false
printf '%s' "$command" | grep -qE '\-\-amend' && amend=true

[ "$amend" = true ] && [ "$(git -C "$cwd" rev-list --no-walk --count --merges HEAD 2>/dev/null)" = "1" ] && exit 0

message=$(printf '%s' "$command" | perl -0777 -ne '
  # Read the flags of the commit invocation only, not another command that
  # shares the line and not the body of an unrelated heredoc.
  exit unless /(?:^|[;&|(])\s*(?:WIP=1\s+)?git\s+(?:-\S+\s+)*commit\b(.*)/s;
  my $rest = $1;

  # Keep the flags up to the first separator that a quote does not protect, so
  # a -m message that spans several lines survives.
  my $flags = "";
  my $quote = "";
  my @c = split //, $rest;
  for (my $i = 0; $i <= $#c; $i++) {
    my $ch = $c[$i];
    if ($quote ne "\x27" && $ch eq "\\" && $i < $#c) {
      $flags .= $ch . $c[++$i];
      next;
    }
    if ($quote ne "") {
      $flags .= $ch;
      $quote = "" if $ch eq $quote;
      next;
    }
    if ($ch eq "\x27" || $ch eq "\"") { $quote = $ch; $flags .= $ch; next }
    last if $ch =~ /[;&|\n]/;
    $flags .= $ch;
  }
  if ($flags =~ /(?:-F|--file)[= ]\s*-(?:\s|$)/) {
    print $2 if $rest =~ /<<-?\x27?"?(\w+)\x27?"?\s*\n(.*?)\n\s*\1/s;
    exit;
  }
  if ($flags =~ /(?:-F|--file)[= ]\s*(\S+)/ && -f $1) {
    open my $f, "<", $1 and print <$f>;
    exit;
  }
  my @m;
  while ($flags =~ /-m\s+"((?:[^"\\]|\\.)*)"/g) { push @m, $1 }
  while ($flags =~ /-m\s+\x27([^\x27]*)\x27/g)  { push @m, $1 }
  print join("\n\n", @m);
')
[ -z "$message" ] && [ "$amend" = true ] &&
  message=$(git -C "$cwd" log -1 --format=%B 2>/dev/null)

subject=$(printf '%s' "$message" | head -1)

if [ "$amend" = true ]; then
  lines=$(zim_production_lines "$cwd" --cached HEAD^)
else
  lines=$(zim_production_lines "$cwd" --cached)
fi

violations=()

case "$subject" in
  wip:*)
    printf '%s' "$command" | grep -q 'WIP=1' ||
      violations+=("A wip: subject needs WIP=1 in the command.") ;;
esac

author_date=""
[ "$amend" = true ] && author_date=$(git -C "$cwd" log -1 --format=%as 2>/dev/null)

while IFS= read -r violation; do
  violations+=("$violation")
done < <(zim_message_violations "$message" "${lines:-0}" "$author_date")

if [ ${#violations[@]} -gt 0 ]; then
  {
    echo "The commit breaks the zim-code style:"
    printf '  - %s\n' "${violations[@]}"
    echo "Fix the message or the split, then commit again."
  } >&2
  exit 2
fi

notes=()
[ -z "$subject" ] &&
  notes+=("The guard could not read the message, so it checked the size only.")
printf '%s' "$subject" | grep -q ' and ' &&
  notes+=("The subject contains \"and\". Check that the commit holds one concern.")
comments=$(git -C "$cwd" diff --cached -U0 -- . "${ZIM_NON_PRODUCTION[@]}" |
  grep -cE '^\+\s*(//|\(\*|#|\*)' || true)
[ "${comments:-0}" -gt 0 ] &&
  notes+=("The diff adds $comments comment lines. Apply the deletion test to each one: a comment that a code reader does not need must go.")

context="Apply the zim-code style: one concern per commit, and the message gives the reason, not the steps."
context="$context The subject reads <type>(<scope>): <lowercase description>, ends with a period, and holds $ZIM_SUBJECT_MAX characters or fewer. The types are:
$(zim_commit_type_table)"
[ ${#notes[@]} -gt 0 ] && context="$context $(printf '%s ' "${notes[@]}")"

jq -n --arg c "$context" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
