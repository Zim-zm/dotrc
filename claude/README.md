# Commit and review setup for Claude Code

Two guards and two reviews, installed per project. A guard is a deterministic
shell script that runs before a tool call. A review is a Claude sub-agent that
sees the diff and the rules, and never the author's context: a reviewer that
shares the author's context inherits the author's excuses.

## What runs, and when

| trigger | what happens | cost |
| --- | --- | --- |
| `git commit` | `zim-commit-guard.sh` refuses a message that breaks a mechanical rule, before git writes it | milliseconds |
| the session stops | a sub-agent reviews the branch against the written rules, once per HEAD sha; in the Gemini CLI, the `AfterAgent` hook runs the same review headless on Flash | 4.8 s median, 52 s on a 10-commit branch, measured over 384 runs |
| `/check-style` | the same review, now, whatever the state of the tree | the same |
| `/deep-review` | a review of the change against its claim, after you approve it | minutes; 17.8 min for one commit of a large OCaml pass |
| any agent spawn | `zim-audit-guard.sh` blocks a deep review that you did not approve | milliseconds |

The style review reports form only. The deep review reports the change. The
deep review runs second, because it decides what to skip from the commit
*type*, and only the style review checks that the type fits the diff.

## Mechanism and policy

The mechanism names no project. A project's policy lives in `projects/<name>/`:

| file | role |
| --- | --- |
| `policy.sh` | the commit types and their table, the subject and body limits, the since-date, the pathspecs that are not production code, the paths that record an output, the opaque paths, the default review base, the rule files, the skills to install |
| the rule files | what only the project can say: which artefact records an output, the print form of its toolchain, the file header, the paths of the size tripwire. `COMMITS.md` here |

`RULES.md` is the general rule file. It is the same in every project, so a
`diff` against this directory shows the drift of an installed copy. The project
file adds to it and never relaxes it; a reviewer that finds the two in conflict
reports the conflict.

## Install

```
git clone git@github.com:Zim-zm/dotrc.git
./dotrc/claude/install.sh --project aegolia --tracked <worktree>
./dotrc/claude/install.sh --project tis-analyzer --local <worktree>
./dotrc/claude/install.sh --with-statusline        # the status line, in your own settings
```

It needs `bash`, `git`, `jq`, `perl`, `awk`, `sha1sum` and `realpath`. It
copies the mechanism and the policy into `<worktree>/hooks/commit/`, with a
`SOURCE` stamp that records the commit it came from, the rule files to the
worktree root, and the skills of the policy into `<worktree>/.claude/skills/`.
Every step is idempotent, so run it again after a pull: the stamp changes, and
`git diff` in the project shows what moved.

Two modes:

- `--tracked` writes the files for you to commit. They propagate by merge to
  every worktree, every machine and every collaborator. The hooks register in
  `.claude/settings.json`.
- `--local` writes the same files at the same paths and keeps them out of git:
  each path goes into the clone's `info/exclude`, which every worktree of the
  clone shares, and the hooks register in `.claude/settings.local.json`. Local
  mode installs no git hook, because a tracked hook cannot source an untracked
  library: the mechanical refusal comes from the Claude guard alone. If a branch
  later tracks a file at one of these paths, `git checkout` refuses to overwrite
  the local copy; remove it before you switch.

Every worktree gets its own install: the files sit inside the worktree, and the
hook commands read `$CLAUDE_PROJECT_DIR`.

The installer also registers the `AfterAgent` hook in `.gemini/settings.json`,
which the Gemini CLI reads from the project. Gemini has no local settings
variant, so local mode leaves that file alone when the branch tracks it. The
Gemini review needs the `gemini` command on the machine; the hook exits quietly
without it.

### The git tier, in tracked mode

The project's own `commit-msg` hook gives the same verdict to every tool, Claude
or not, when it sources the vendored library:

```bash
source "$(dirname "$0")/commit/zim-rules.sh"
violations=$(zim_diff_violations "$PWD" "$(cat "$1")" "" --cached)
[ -z "$violations" ] || { printf '%s\n' "$violations" >&2; exit 1; }
```

### Uninstall

Delete what the installer wrote, by hand: `hooks/commit/`, `RULES.md`, the
project's rule file, `.claude/skills/<skill>` for each skill of the policy, the
four entries in the settings file, and, in local mode, the lines in
`info/exclude`. A previous global install lived in `~/.claude/zim`, with three
skills linked into `~/.claude/skills/` and four entries in
`~/.claude/settings.json`; remove those the same way.

## The files

| file | role |
| --- | --- |
| `zim-paths.sh` | the state directory, the per-worktree key, the diff helpers, the comment syntax of each extension, the review base. It sources `policy.sh` |
| `zim-rules.sh` | every rule a script can decide, and the pure-refactor test |
| `zim-commit-guard.sh` | `PreToolUse` on `Bash`: judges a commit message before git writes it, in a worktree of its own project |
| `zim-review-gate.sh` | decides whether a review is due, prints what to review, prints the brief of a deep review, and holds the state modes |
| `zim-review-agent.md` | the procedure that the reviewing sub-agent follows |
| `zim-audit-guard.sh` | `PreToolUse` on `Agent`: blocks an unapproved deep review and consumes the approval |
| `zim-stop-hook-prompt.txt` | the prompt that the Claude `Stop` hook runs |
| `zim-gemini-after-agent.sh` | the Gemini `AfterAgent` hook: runs the gate, then the reviewer headless with the diff on stdin, records a pass, and hands a finding back to the agent |
| `RULES.md` | the general rule file, which the reviewer reads before the project file |
| `projects/<name>/` | the policy and the rule file of one project |
| `skills/check-style/` | the on-demand style review |
| `skills/deep-review/` | the deep review, with its approval step |
| `skills/zim-code/` | a pointer to the two rule files, for a project whose sessions do not receive them at commit time |
| `install.sh` | the installer |
| `sta-line.sh` | the status line: model, effort, branch, context, rate limits. Unrelated to the review |

## The mechanical rules

1. The subject reads `type(scope)!: lowercase description.` The type is
   mandatory, the scope is optional, `!` marks a breaking change, and the
   description ends with a period.
2. The type comes from `ZIM_COMMIT_TYPES`, a closed list of 11. The policy's
   table states what each one covers.
3. The subject holds `ZIM_SUBJECT_MAX` characters or fewer, 100 by default.
4. A blank line separates the subject and the body. Each body line holds
   `ZIM_BODY_MAX` characters or fewer, 80 by default. A trailer and a line
   without a space are exempt.
5. The message carries exactly one `Assisted-by:` trailer and no
   `Co-Authored-By:`.
6. A `test:` commit changes no production line. A `doc:` commit changes no
   production line of code, so it may change a comment. Otherwise it is a
   `feat:` or a `fix:`.
7. Over 100 production lines need an `Atomic:` or a `Mechanical:` line, which
   says why the commit cannot be split.
8. A `refactor:`, a `style:` or a `perf:` commit that changes a recorded output
   carries an `Output-justification:` line, which says why the results are the
   same.
9. A body sentence holds `ZIM_SENTENCE_MAX` words or fewer, 25 by default, the
   ASD-STE100 limit for a descriptive sentence. A block that opens with a
   `Word:` prefix is exempt, as it is for rule 4.
10. A `feat:`, a `fix:` or a `perf:` commit carries no `Mechanical:` line. A
    mechanical sweep is its own `refactor:` commit before it.

Three escapes: a `wip:` subject needs `WIP=1` in the command and skips every
other rule; a subject that a tool writes (`Revert "…"`, `fixup!`, `squash!`,
`Merge …`) is exempt; a commit whose author date precedes
`ZIM_CONVENTIONAL_SINCE` keeps the style of its time, and answers to rules 5
to 10 only for the `Co-Authored-By:` ban and the size line.

The comment syntax table in `zim-paths.sh` names the extensions it knows. An
extension it does not name keeps every changed line, so a `doc:` commit that
touches such a file stays refused. The test reads one line at a time, so an
interior line of a block comment that carries no delimiter counts as code, and
the deletion of the two delimiters around live code counts as a comment change.
The style review reads the whole diff and catches the second case.

The models: Sonnet 5 for the style review, Opus 5 for the deep review, and
`gemini-2.5-flash` for the style review under the Gemini CLI. Do not use Haiku
for a review: 384 recorded runs on Haiku reported a finding zero times.

## Two grades

A finding is **blocking** when the shape of the diff is wrong: the type, the
concerns, a hidden refactor, a missing test commit, a duplication. It is a
**note** when the words could be better: a derivable clause, a word outside the
controlled language, a comment, a name. A pass stands with notes, so a note
never withholds the record and never blocks a push; the user reads it and
decides. Without the grade, every fix made a new HEAD, the new HEAD drew a new
sample of the reviewer's opinion, and the cycle ended only when a sample
happened to return nothing.

## Opaque files

`ZIM_OPAQUE` in the policy names the paths whose text a reviewer never needs:
recordings, lockfiles, generated data. A binary file is opaque whatever its
path, by git's own detection. The diff file carries the stat line of an opaque
file and never its patch, so a 25,000-line recording cannot fill the 6000-line
cap and blind the review of the code after it. The brief of a deep review
counts the behaviour files without them, and prints how many opaque files the
range touched.

## The review base

The style review covers `<base>..HEAD`. The gate takes the first of these that
answers:

1. `zim.<branch>.reviewBase`. A branch lives in at most one worktree, so this
   key is per worktree in practice.
2. `zim.reviewBase`. Every worktree of a repository shares this one, because it
   lives in `.git/config`.
3. the nearest branch tip inside the history of HEAD, when it is nearer than
   step 4. A stacked branch needs no key: the branch below it is that tip.
4. the first integration branch that shares history with HEAD: `origin/HEAD`,
   then `ZIM_BASE_DEFAULT`, `origin/main`, `origin/master` and
   `origin/develop`. A merge-base accepts it, so a branch that moves after you
   leave it stays the base.
5. `ZIM_BASE_DEFAULT`, from the policy.

Step 3 walks the history of HEAD and stops at the base of step 4, so a
repository that holds 500 branches answers in milliseconds. It cannot tell the
branch below from a stale local branch left in your history. The gate prints its
choice and the reason, so a wrong base is visible in the first lines of the
payload:

```
base: rust/coerce-unsized-dyn (the nearest ancestor, 3 commits below HEAD)
```

Override it for one branch:

```
git -C <worktree> config zim.<branch>.reviewBase <the branch below>
```

The deep review reads the target branch of the merge request first, through
`glab`, and falls back to the same finder.

## The state directory

`~/.claude/zim-review-state/` holds four kinds of file, one set per worktree,
for every project on the machine:

| file | meaning |
| --- | --- |
| `<key>` | the last HEAD that a style review covered, so it blocks at most once per sha. A push gate can read it with `--reviewed-head` |
| `<key>.diff` | the material of that review, up to 6000 lines |
| `<key>.passed` | the HEAD whose style review found nothing. The deep review requires it |
| `<key>.review-approved` | your approval for one deep review. The guard deletes it when it lets one through |

## What it never does

- No style reviewer builds anything, runs a test, or writes a file. A deep
  reviewer runs the harness only where the project's review rulebook allows it.
- No deep review starts without your explicit approval.
- No review reports a rule that the gate already decided; it copies the gate's
  verdict instead.
