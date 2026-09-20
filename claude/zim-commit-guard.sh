#!/bin/bash
# PreToolUse guard on Bash. Blocks a `git commit` that breaks a mechanical rule
# of the commit style, and injects the rules that need judgment.

set -u

source "$(dirname "${BASH_SOURCE[0]}")/zim-paths.sh"
source "$(dirname "${BASH_SOURCE[0]}")/zim-rules.sh"

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')

# The command position matters: prose inside a heredoc mentions a command
# without running it.
printf '%s' "$command" |
  grep -qE '(^|[;&|(]|&&|\|\|)[[:space:]]*(WIP=1[[:space:]]+)?git[[:space:]]+(((-C|-c|--git-dir|--work-tree|--namespace|--exec-path)[= ][[:space:]]*[^ ]+|-[^ ]+)[[:space:]]+)*commit([[:space:]]|$)' ||
  exit 0

# The hook runs in the session directory, and the command can name another
# repository, with git -C or with a leading cd.
named=$(printf '%s' "$command" | perl -0777 -ne '
  exit unless /(?:^|[;&|(])\s*(?:WIP=1\s+)?git\s+((?:(?:(?:-C|-c|--git-dir|--work-tree|--namespace|--exec-path)[= ]\s*\S+|-\S+)\s+)*)commit\b/s;
  my ($path) = $1 =~ /(?:^|\s)-C[= ]\s*(\S+)/;
  print $path if defined $path;
')
[ -n "$named" ] ||
  named=$(printf '%s' "$command" |
    perl -0777 -ne 'print $1 if /^\s*cd\s+(\S+)\s*(?:&&|;)/')

target="$cwd"
if [ -n "$named" ]; then
  case "$named" in /*) named_path="$named" ;; *) named_path="$cwd/$named" ;; esac
  if [ -d "$named_path" ]; then
    target="$named_path"
  else
    jq -n --arg c "The guard judged nothing. The command names the repository $named, and that path does not resolve here, so the guard cannot read its index. Name a literal path to get the mechanical checks." \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
    exit 0
  fi
fi

[ "$(git -C "$target" rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ] || exit 0

case "$target" in /tmp/*|*/scratchpad/*) exit 0 ;; esac

# The guard judges a worktree of its own project, and no other: a commit in
# another project answers to that project's guard, or to none.
target_policy="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null)/hooks/commit/policy.sh"
[ -f "$target_policy" ] && grep -q "^ZIM_PROJECT=$ZIM_PROJECT\$" "$target_policy" || exit 0

git_dir=$(git -C "$target" rev-parse --git-dir 2>/dev/null)
[ -f "$git_dir/MERGE_HEAD" ] && exit 0

amend=false
printf '%s' "$command" | grep -qE '\-\-amend' && amend=true

[ "$amend" = true ] && [ "$(git -C "$target" rev-list --no-walk --count --merges HEAD 2>/dev/null)" = "1" ] && exit 0

message=$(printf '%s' "$command" | perl -0777 -ne '
  # Read the flags of the commit invocation only, not another command that
  # shares the line and not the body of an unrelated heredoc.
  exit unless /(?:^|[;&|(])\s*(?:WIP=1\s+)?git\s+(?:(?:(?:-C|-c|--git-dir|--work-tree|--namespace|--exec-path)[= ]\s*\S+|-\S+)\s+)*commit\b(.*)/s;
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
    open(my $f, "<", $1) or exit;
    print <$f>;
    exit;
  }
  my @m;
  while ($flags =~ /-m\s+"((?:[^"\\]|\\.)*)"/g) { push @m, $1 }
  while ($flags =~ /-m\s+\x27([^\x27]*)\x27/g)  { push @m, $1 }
  print join("\n\n", @m);
')
names_message=false
printf '%s' "$command" |
  grep -qE '(^|[[:space:]])(-m|--message|-F|--file)([[:space:]]|=)' && names_message=true

[ -z "$message" ] && [ "$amend" = true ] && [ "$names_message" = false ] &&
  message=$(git -C "$target" log -1 --format=%B 2>/dev/null)

subject=$(printf '%s' "$message" | head -1)

diff_range=(--cached)
[ "$amend" = true ] && diff_range+=(HEAD^)

violations=()

case "$subject" in
  wip:*)
    printf '%s' "$command" | grep -q 'WIP=1' ||
      violations+=("A wip: subject needs WIP=1 in the command.") ;;
esac

author_date=""
[ "$amend" = true ] && author_date=$(git -C "$target" log -1 --format=%as 2>/dev/null)

while IFS= read -r violation; do
  violations+=("$violation")
done < <(zim_diff_violations "$target" "$message" "$author_date" "${diff_range[@]}")

if [ ${#violations[@]} -gt 0 ]; then
  {
    echo "The commit breaks the commit style of $ZIM_PROJECT:"
    printf '  - %s\n' "${violations[@]}"
    echo "Fix the message or the split, then commit again."
  } >&2
  exit 2
fi

notes=()
[ -z "$subject" ] &&
  notes+=("The guard could not read the message, so it checked the size only. It runs before the command, so a message file that the same command writes does not exist yet. Write that file in an earlier call.")
printf '%s' "$subject" | grep -q ' and ' &&
  notes+=("The subject contains \"and\". Check that the commit holds one concern.")
comments=$(git -C "$target" diff --cached -U0 -- . "${ZIM_NON_PRODUCTION[@]}" |
  grep -cE '^\+\s*(//|\(\*|#|\*)' || true)
[ "${comments:-0}" -gt 0 ] &&
  notes+=("The diff adds $comments comment lines. Apply the deletion test to each one: a comment that a code reader does not need must go.")

context="Apply the commit style: one concern per commit, and the message gives the reason, not the steps."
context="$context The subject reads <type>(<scope>): <lowercase description>, ends with a period, and holds $ZIM_SUBJECT_MAX characters or fewer. The types are:
$(zim_commit_type_table)"
[ ${#notes[@]} -gt 0 ] && context="$context $(printf '%s ' "${notes[@]}")"

jq -n --arg c "$context" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $c}}'
