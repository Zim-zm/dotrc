# Commit and review setup for Claude Code

Two guards and two reviews. A guard is a deterministic shell script that runs
before a tool call. A review is a Claude sub-agent that sees the diff and the
rules, and never the author's context: a reviewer that shares the author's
context inherits the author's excuses.

## What runs, and when

| trigger | what happens | cost |
| --- | --- | --- |
| `git commit` | `zim-commit-guard.sh` refuses a message that breaks a mechanical rule, before git writes it | milliseconds |
| the session stops | a sub-agent reviews the branch against the written rules, once per HEAD sha | 4.8 s median, 52 s on a 10-commit branch, measured over 384 runs |
| `/zim-review` | the same review, now, whatever the state of the tree | the same |
| `/zim-audit` | a deep review of the change itself, after you approve it | minutes; 17.8 min for one commit of a large OCaml pass |
| any agent spawn | `zim-audit-guard.sh` blocks a deep audit that you did not approve | milliseconds |

The style review reports form only. The deep audit reports the change. The
audit runs second, because it decides what to skip from the commit *type*, and
only the style review checks that the type fits the diff.

## Install

```
git clone git@github.com:Zim-zm/dotrc.git
./dotrc/claude/install.sh                 # --with-statusline adds the status line
```

It needs `bash`, `git`, `jq`, `perl`, `awk` and `sha1sum`. It links
`~/.claude/zim` to this directory, links the three skills into
`~/.claude/skills/`, and merges four entries into `~/.claude/settings.json`,
after copying it to `settings.json.zim-backup`. Every step is idempotent, so run
it again after a pull.

## The files

| file | role |
| --- | --- |
| `zim-paths.sh` | the paths that are not production code, the comment syntax of each extension, the state directory, the per-worktree key |
| `zim-rules.sh` | every rule a script can decide, the type table, the pure-refactor test |
| `zim-commit-guard.sh` | `PreToolUse` on `Bash`: judges a commit message before git writes it |
| `zim-review-gate.sh` | decides whether a review is due, prints what to review, and holds the state modes |
| `zim-review-agent.md` | the procedure that the reviewing sub-agent follows |
| `zim-audit-guard.sh` | `PreToolUse` on `Agent`: blocks an unapproved deep audit and consumes the approval |
| `zim-stop-hook-prompt.txt` | the prompt that the `Stop` hook runs |
| `skills/zim-code/` | the written rules, which the reviewer reads as its rule file |
| `skills/zim-review/` | the on-demand style review |
| `skills/zim-audit/` | the deep audit, with its approval step |
| `install.sh` | the installer |
| `sta-line.sh` | the status line: model, effort, branch, context, rate limits. Unrelated to the review |

## The mechanical rules

1. The subject reads `type(scope)!: lowercase description.` The type is
   mandatory, the scope is optional, `!` marks a breaking change, and the
   description ends with a period.
2. The type comes from `ZIM_COMMIT_TYPES`, a closed list of 11. `zim-rules.sh`
   states what each one covers.
3. The subject holds 100 characters or fewer.
4. A blank line separates the subject and the body. Each body line holds 80
   characters or fewer. A trailer and a line without a space are exempt.
5. The message carries exactly one `Assisted-by:` trailer and no
   `Co-Authored-By:`.
6. A `test:` commit changes no production line. A `doc:` commit changes no
   production line of code, so it may change a comment. Otherwise it is a
   `feat:` or a `fix:`.
7. Over 100 production lines need an `Atomic:` or a `Mechanical:` line, which
   says why the commit cannot be split.
8. A `refactor:`, a `style:` or a `perf:` commit that changes an oracle carries
   an `Output-justification:` line, which says why the results are the same.

Three escapes: a `wip:` subject needs `WIP=1` in the command and skips every
other rule; a subject that a tool writes (`Revert "…"`, `fixup!`, `squash!`) is
exempt; a commit whose author date precedes `ZIM_CONVENTIONAL_SINCE` keeps the
style of its time.

## What is policy, and yours to change

The mechanism is general. These choices are not:

- `ZIM_COMMIT_TYPES` and the type table in `zim-rules.sh`. The table names
  `.gitlab-ci.yml`, dune and opam.
- The final period on the subject. commitlint forbids it; this setup requires
  it.
- The `Assisted-by:` trailer, and the refusal of `Co-Authored-By:`.
- `ZIM_SUBJECT_MAX`, `ZIM_BODY_MAX`, and the threshold of 100 production lines.
- `ZIM_CONVENTIONAL_SINCE`. Set it to the day you start.
- `ZIM_NON_PRODUCTION` in `zim-paths.sh`. It is shaped for a repository with
  `tests/`, `oracle/` and `doc/` directories.
- `ZIM_RECORDED_OUTPUT` in `zim-paths.sh`. It names the paths that record a
  result: `oracle/`, `*/oracle/*` and `*.oracle`.
- `zim_comment_markers` in `zim-paths.sh`. It names the comment syntax of each
  extension. An extension it does not name keeps every changed line, so a
  `doc:` commit that touches such a file stays refused. The test reads one line
  at a time, so an interior line of a block comment that carries no delimiter
  counts as code, and the deletion of the two delimiters around live code counts
  as a comment change. The style review reads the whole diff and catches the
  second case.
- `skills/zim-code/SKILL.md`. It holds the written rules, including a
  merge-request section for GitLab.
- The models: Sonnet 5 for the style review, Opus 5 for the audit. Do not use
  Haiku for a review: 384 recorded runs on Haiku reported a finding zero times.

## Stacked branches

The review covers `<base>..HEAD`, and the base is `origin/master` by default. A
branch stacked on another one reviews the whole stack until you say otherwise:

```
git -C <worktree> config zim.reviewBase <the branch below>
```

## The state directory

`~/.claude/zim-review-state/` holds four kinds of file, one set per worktree:

| file | meaning |
| --- | --- |
| `<key>` | the last HEAD that the automatic review covered, so it blocks at most once per sha |
| `<key>.diff` | the material of that review, up to 6000 lines |
| `<key>.passed` | the HEAD whose style review found nothing. The audit requires it |
| `<key>.audit-approved` | your approval for one audit. The guard deletes it when it lets one through |

## What it never does

- No reviewer builds anything, runs a test, or writes a file.
- No deep audit starts without your explicit approval.
- No review reports a rule that the gate already decided; it copies the gate's
  verdict instead.
