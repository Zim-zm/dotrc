# The rules of the zim-code commit style that a script can decide.
# Sourced by zim-commit-guard.sh, which checks a commit before git makes it,
# and by zim-review-gate.sh, which checks the commits of a branch.

[ -n "${ZIM_NON_PRODUCTION_PATHS+x}" ] ||
  source "$(dirname "${BASH_SOURCE[0]}")/zim-paths.sh"

ZIM_COMMIT_TYPES="feat fix refactor perf test doc style ci build revert wip"
ZIM_SUBJECT_MAX=100
ZIM_BODY_MAX=80

# A commit whose author date precedes this day keeps the style of its time.
ZIM_CONVENTIONAL_SINCE="2026-09-08"

zim_commit_type_table() {
  cat <<'TABLE'
feat      a capability the project did not have: a feature, an option, a supported construct
fix       a wrong result, a crash or a wrong message, in behaviour already claimed
refactor  a code change with no change of any result: a rename, a move, an extraction, an inlining, a dead-code removal
perf      a speed or a memory gain with no change of any result
test      a test, a run.config or an oracle; it changes no production line
doc       documentation only: a document, or a comment in code; it changes no code line
style     formatting only: a formatter run, whitespace, a line wrap; it renames nothing
ci        the pipeline: .gitlab-ci.yml, the runner images, the release scripts
build     the build and the dependencies: dune, opam, the Makefile, build(deps): for a bump
revert    a hand-written revert; the body names the reverted commit
wip       a snapshot; it needs WIP=1 in the command and skips the other message rules
TABLE
}

zim_subject_is_generated() {
  # A subject that git or the GitLab interface writes, which the author cannot
  # choose.
  case "$1" in
    'Revert "'*|'fixup! '*|'squash! '*) return 0 ;;
  esac
  printf '%s' "$1" | grep -qE '^Apply [0-9]+ suggestion\(s\) to [0-9]+ file\(s\)$'
}

zim_subject_prefix() {
  # Prints the word before the colon of a conventional subject, known or not.
  printf '%s' "$1" | sed -nE 's|^([a-z]+)(\([a-z0-9/_.-]+\))?!?: .*|\1|p'
}

zim_type_is_known() {
  case " $ZIM_COMMIT_TYPES " in *" $1 "*) return 0 ;; esac
  return 1
}

zim_is_pure_refactor() {
  # $1: git directory, $2: a commit. True when the commit changes the code
  # without changing what any test, oracle or document records. Such a commit
  # needs no deep audit; the style review still covers it.
  local dir="$1" sha="$2" prefix
  prefix=$(zim_subject_prefix "$(git -C "$dir" log -1 --format=%s "$sha")")
  case "$prefix" in
    refactor|style) ;;
    *) return 1 ;;
  esac
  [ -z "$(zim_non_production_files "$dir" "$sha^!" | head -1)" ]
}

zim_message_violations() {
  # $1: the full commit message, $2: the production line count, $3: the author
  # date as YYYY-MM-DD, empty for a commit that does not exist yet, $4: the
  # production lines that hold code, which defaults to $2.
  local message="$1"
  local production_lines="${2:-0}"
  local author_date="${3:-}"
  local code_lines="${4:-$production_lines}"
  local subject prefix assisted types_re length second conventional=true

  subject=$(printf '%s\n' "$message" | head -1)
  [ -z "$subject" ] && return 0
  zim_subject_is_generated "$subject" && return 0

  prefix=$(zim_subject_prefix "$subject")
  [ "$prefix" = wip ] && return 0

  [ -n "$author_date" ] && [ "$author_date" \< "$ZIM_CONVENTIONAL_SINCE" ] &&
    conventional=false

  case "$subject" in
    *.) ;;
    *) echo "The subject does not end with a period: \"$subject\"" ;;
  esac

  printf '%s\n' "$message" | grep -qi '^Co-Authored-By:' &&
    echo "The message carries a Co-Authored-By: trailer. Use Assisted-by: alone."
  assisted=$(printf '%s\n' "$message" | grep -ci '^Assisted-by:')
  case "$assisted" in
    1) ;;
    0) echo "The message carries no Assisted-by: trailer." ;;
    *) echo "The message carries $assisted Assisted-by: trailers, not exactly one." ;;
  esac

  if [ "$production_lines" -gt 100 ]; then
    printf '%s\n' "$message" | grep -qE '^(Atomic|Mechanical):' ||
      echo "The commit changes $production_lines production lines and carries no Atomic: or Mechanical: line."
  fi

  [ "$conventional" = false ] && return 0

  types_re=$(printf '%s' "$ZIM_COMMIT_TYPES" | tr ' ' '|')
  if ! printf '%s' "$subject" |
       grep -qE "^($types_re)(\([a-z0-9/_.-]+\))?!?: [a-z]"; then
    if [ -n "$prefix" ] && ! zim_type_is_known "$prefix"; then
      echo "The subject prefix \"$prefix\" is not a commit type. Use one of: $ZIM_COMMIT_TYPES"
    elif printf '%s' "$subject" |
         grep -qE "^($types_re)(\([a-z0-9/_.-]+\))?!?: "; then
      echo "The description does not start with a lowercase letter: \"$subject\""
    else
      echo "The subject does not read as <type>(<scope>): <lowercase description>. \"$subject\" The types are: $ZIM_COMMIT_TYPES"
    fi
  fi

  length=${#subject}
  [ "$length" -gt "$ZIM_SUBJECT_MAX" ] &&
    echo "The subject holds $length characters, more than $ZIM_SUBJECT_MAX."

  case "$prefix" in
    test)
      [ "$production_lines" -gt 0 ] &&
        echo "A test: commit changes $production_lines production lines. Use feat: or fix:, or move the production change to its own commit." ;;
    doc)
      [ "$code_lines" -gt 0 ] &&
        echo "A doc: commit changes $code_lines production code lines. Use feat: or fix:, or move the production change to its own commit." ;;
  esac

  second=$(printf '%s\n' "$message" | sed -n 2p)
  [ -n "$second" ] &&
    echo "The line after the subject is not empty: \"$second\""

  printf '%s\n' "$message" | awk -v max="$ZIM_BODY_MAX" '
    NR > 2 && length($0) > max && /[[:space:]]/ &&
    !/^([A-Z][A-Za-z-]*|BREAKING[ -]CHANGE): / {
      printf "Body line %d holds %d characters, more than %d: \"%s...\"\n",
        NR, length($0), max, substr($0, 1, 40)
    }'

  return 0
}
