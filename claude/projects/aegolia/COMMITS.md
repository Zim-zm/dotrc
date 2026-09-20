# COMMITS.md

Project clarifications to `RULES.md` for this repository. `RULES.md` states
the principle; this file names the artefacts. It adds to the general file and
never relaxes it. A session receives both files at commit time, not before: the
fix and its presentation stay separate concerns (`docs/commit-workflow.md`).

## The recorded output

A committed fixture of `test_cases/` carries the `refs` the pipeline produced
for its `text`. That snapshot is the recorded output of this repository:

- The `test:` commit that reproduces a defect adds or extends a fixture with the
  wrong `refs` the code produces today, so the commit stays green. The `fix:`
  commit changes the `refs`, and its diff shows the exact behavioral delta. A
  Rust or node test pins the wrong value the same way.
- A `refactor:`, a `style:` or a `perf:` commit that changes the `refs` of a
  committed fixture carries an `Output-justification:` line.
- The generated fixtures (`article_extraction.json`, `code_names.json`) are not
  committed, so they record nothing.

No toolchain here prints an artefact into a recording, so the print rule of
`RULES.md` does not apply.

## Production lines

The size tripwire counts the changed lines outside `tests/`, `client/tests/`,
`test_cases/`, `test_samples/`, `docs/` and every Markdown file. The commit
guard and the `commit-msg` hook compute it from `hooks/commit/policy.sh`; to
see it before you commit, run:

```
git diff --cached --stat -- . ':!tests' ':!client/tests' ':!test_cases' ':!test_samples' ':!docs' ':!*.md'
```

Over 100 lines, the message carries an `Atomic: <reason>` line or a
`Mechanical: <tool>` line, as `RULES.md` says.

## The commit types

`hooks/commit/policy.sh` holds the type table; the guard prints it at commit
time. Two rows are worth naming here:

- `refactor` covers what this repository used to call plumbing: a rename, a
  move, a signature threaded through its call sites. A large sweep carries the
  `Mechanical:` line.
- `build` covers the repository tooling as well as the build: the hooks, the
  agent settings, `xtask`, the lockfiles.

Commits older than 2026-09-21 follow the former grammar; the guard and the
reviewer exempt them by author date.

## Operations that always commit alone

- **Renames and moves** — for diff readability.
- **Extraction and inlining** — byte-faithful: code moves, nothing changes.
  Behavior changes to the moved code come in a following commit.
- **Dead-code removal** — a deletion diff answers one question ("is this really
  unreachable?"); never bury it in a feature diff.
- **Mechanical output** — autofixes (`eslint --fix`, `cargo clippy --fix`),
  rustfmt after a config change, search-and-replace sweeps. The commit carries
  a `Mechanical:` line and mixes no manual edit in.
- **Dependency bumps** — the bump plus the minimal compatibility fixes is one
  `build(deps):` commit; adopting the new version's APIs is a separate commit
  after it.

## Discipline

- Before editing, state the intended commit sequence. Preparatory refactor
  commits come first, each compiling and green, so the final feature commit is
  minimal.
- Spiking a full draft to discover the shape is fine — but then reset and build
  the sequence for real. Every commit must be a state that actually existed,
  compiled, and passed the hook. Never carve commits out of a finished tree
  with `git add -p`.
- Where no harness can reach the change (git hooks, agent definitions,
  settings), the commit body states how the author validated it instead.
- Each commit must compile, pass all tests, and pass all lints: the pre-commit
  hook runs `cargo xtask build` and `cargo xtask check`.

## Comments

`RULES.md` says when a comment exists at all. In this repository:

- No section banners or step numbering, no comments that restate the
  signature, no doc comments on trivial or private items.
- No comments addressed at a reviewer, and no history narration ("replaces the
  old X", "this used to be…"). A comment describes the current state of the
  code; history belongs in the commit message.
- Match the surrounding file's comment density.
- Before each commit, re-read the diff and delete every comment that fails the
  deletion test.
- The controlled language of `AGENTS.md` applies: 20 words in a comment
  sentence.
- In a test, a comment that names the scenario or the expected behavior
  passes the deletion test: the assertion shows the value, not why the case
  matters.

## File headers

This repository has no file header. A source file starts with its code.

## Savepoints and the presentation phase

- A savepoint is a `wip:` commit created with `WIP=1 git commit -m "wip:
  <state>"`; it may be red. A `wip:` commit never reaches an MR.
- The presentation phase starts from a green tree. Back up the branch, reset to
  the review base, and rebuild the sequence stepwise: bring the working tree to
  each planned state and let the pre-commit hook validate it for real. The wip
  trail is input for grouping and order, never material to carve from.
- After the rebuild, the diff against the backup must be empty.
