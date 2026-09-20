# The rules of the commit style that a script can decide. Sourced by
# zim-commit-guard.sh, which checks a commit before git makes it, by the
# commit-msg git hook of a project, and by zim-review-gate.sh, which checks the
# commits of a branch. The values come from policy.sh, through zim-paths.sh.

[ -n "${ZIM_NON_PRODUCTION_PATHS+x}" ] ||
  source "$(dirname "${BASH_SOURCE[0]}")/zim-paths.sh"

zim_subject_is_generated() {
  # A subject that git or the GitLab interface writes, which the author cannot
  # choose.
  case "$1" in
    'Revert "'*|'fixup! '*|'squash! '*|'Merge '*) return 0 ;;
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
  # without changing what any test, recorded output or document records. Such a
  # commit needs no deep review; the style review still covers it.
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
  # production lines that hold code, which defaults to $2, $5: a recorded output
  # file that the diff changes, empty when the diff changes none.
  local message="$1"
  local production_lines="${2:-0}"
  local author_date="${3:-}"
  local code_lines="${4:-$production_lines}"
  local recorded_output="${5:-}"
  local subject prefix assisted types_re length second conventional=true

  subject=$(printf '%s\n' "$message" | head -1)
  [ -z "$subject" ] && return 0
  zim_subject_is_generated "$subject" && return 0

  prefix=$(zim_subject_prefix "$subject")
  [ "$prefix" = wip ] && return 0

  [ -n "$author_date" ] && [ "$author_date" \< "$ZIM_CONVENTIONAL_SINCE" ] &&
    conventional=false

  printf '%s\n' "$message" | grep -qi '^Co-Authored-By:' &&
    echo "The message carries a Co-Authored-By: trailer. Use Assisted-by: alone."

  if [ "$production_lines" -gt 100 ]; then
    printf '%s\n' "$message" | grep -qE '^(Atomic|Mechanical):' ||
      echo "The commit changes $production_lines production lines and carries no Atomic: or Mechanical: line."
  fi

  # A commit older than the policy's since-date keeps the style of its time:
  # the rules above held before that day, the rules below did not.
  [ "$conventional" = false ] && return 0

  assisted=$(printf '%s\n' "$message" | grep -ci '^Assisted-by:')
  case "$assisted" in
    1) ;;
    0) echo "The message carries no Assisted-by: trailer." ;;
    *) echo "The message carries $assisted Assisted-by: trailers, not exactly one." ;;
  esac

  case "$subject" in
    *.) ;;
    *) echo "The subject does not end with a period: \"$subject\"" ;;
  esac

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

  case "$prefix" in
    feat|fix|perf)
      printf '%s\n' "$message" | grep -qE '^Mechanical:' &&
        echo "A $prefix: commit carries a Mechanical: line. A mechanical sweep is its own refactor: commit before this one. Use Atomic: when this commit cannot be split." ;;
  esac

  if [ -n "$recorded_output" ]; then
    case "$prefix" in
      refactor|style|perf)
        printf '%s\n' "$message" | grep -q '^Output-justification:' ||
          echo "A $prefix: commit changes $recorded_output and carries no Output-justification: line, which says why the results are the same." ;;
    esac
  fi

  second=$(printf '%s\n' "$message" | sed -n 2p)
  [ -n "$second" ] &&
    echo "The line after the subject is not empty: \"$second\""

  printf '%s\n' "$message" | awk -v max="$ZIM_BODY_MAX" '
    NR > 2 && length($0) > max && /[[:space:]]/ &&
    !/^([A-Z][A-Za-z-]*|BREAKING[ -]CHANGE): / {
      printf "Body line %d holds %d characters, more than %d: \"%s...\"\n",
        NR, length($0), max, substr($0, 1, 40)
    }'

  printf '%s\n' "$message" | awk -v max="$ZIM_SENTENCE_MAX" '
    NR <= 2 { next }
    /^([A-Z][A-Za-z-]*|BREAKING[ -]CHANGE): / { skip = 1; next }
    /^[[:space:]]*$/ { skip = 0; next }
    skip { next }
    { prose = prose " " $0 }
    END {
      n = split(prose " ", sentence, /[.?!] +/)
      for (i = 1; i <= n; i++) {
        words = split(sentence[i], word, /[[:space:]]+/)
        count = 0
        for (j = 1; j <= words; j++) if (word[j] != "") count++
        if (count > max) {
          text = sentence[i]
          sub(/^[[:space:]]+/, "", text)
          printf "Body sentence %d holds %d words, more than %d: \"%s...\"\n",
            i, count, max, substr(text, 1, 40)
        }
      }
    }'

  return 0
}

zim_diff_violations() {
  # $1: git directory, $2: the full commit message, $3: the author date as
  # YYYY-MM-DD or empty, remaining arguments: the diff range of the commit, or
  # --cached for a commit that does not exist yet. Measures the diff, then
  # prints the violations of the message, one per line.
  local dir="$1" message="$2" author_date="$3"; shift 3
  local lines code_lines recorded_output
  lines=$(zim_production_lines "$dir" "$@")
  code_lines=$(zim_production_code_lines "$dir" "$@")
  recorded_output=$(zim_recorded_output_files "$dir" "$@" | head -1)
  zim_message_violations "$message" "${lines:-0}" "$author_date" \
    "${code_lines:-0}" "$recorded_output"
}
