---
name: deep-review
description: Deep review of a branch, or of one named commit, in a clean sub-agent - the change against its claim, and its correctness, not its style. Use when an implementation task ends, or when the user asks for a deep review, a functional review, an audit, or a self-review of a branch or a commit. It always asks the user before it spends anything.
---

# Deep review

The style review judges the form of a commit. This judges the change itself:
what it claims, whether it does it, and whether the result is right. It costs
minutes and millions of tokens, so the user approves every run.

`$1` names what to review: a commit, a range, a reading of the claim from an
earlier run, or nothing.

## Two ways in

**A named commit or range** — `/deep-review f2aa416c` or `/deep-review
base..HEAD`. Review exactly what the user names, whatever its type, and whatever
any test says. Go straight to step 3. The user's request overrides both filters
below, and the commit type decides nothing here, so the style pass is not
needed.

**No target, or a reading of the claim** — review the branch. Run step 1 and
step 2 first.

## 1. The style review passes first

```
hooks/commit/zim-review-gate.sh "$PWD" false --check-pass
```

- `PASSED`: go to step 2.
- `NOT PASSED`: invoke the `check-style` skill, and return here when it finds
  nothing. Never skip this step. Step 2 reads the type of each commit, and only
  the style review checks that the type fits the diff. A commit named
  `refactor:` that changes behaviour would escape the review.

## 2. The brief

```
hooks/commit/zim-review-gate.sh "$PWD" false --brief
```

The brief names the base — the target branch of the merge request when one
exists, else the review base — the range, its size in behaviour files and
lines, each commit with its diff size and its verdict, and the rule files.

A commit marked `pure refactor` changes no test, no recorded output and no
document, so the style review covers it alone. When every commit is one,
report that and stop. Spawn no agent, and ask nothing.

## 3. Ask the user, always

Report, in a few lines:

- each commit the review would cover: the short sha, the subject, and the size
  of its diff, from the brief;
- the size of the range. Above about 40 behaviour files or about 3000 lines,
  say that the reviewer will read the files that carry the claim deeply and
  scan the rest, and that a smaller range gets a fuller read;
- the model: Opus 5;
- the one cost measurement on record: 17.8 minutes and 11.5 M input tokens for
  one commit of a large OCaml pass, on 2026-09-08.

Then ask with `AskUserQuestion`. Offer three answers: review every commit
listed, review a part of them, or skip the review. Spawn nothing before the
answer.

When the user skips, drop the subject. Do not propose the same review again.

When the user approves, record it:

```
hooks/commit/zim-review-gate.sh "$PWD" false --approve-review "<the commits>"
```

## 4. One sub-agent for the whole target

Spawn exactly one agent with the `Agent` tool:

- `subagent_type`: `general-purpose`
- `model`: `opus`
- `prompt`: its **first line is `ZIM-DEEP-REVIEW`**, alone.
  `zim-audit-guard.sh` reads that marker, checks the approval, and consumes it.
  Without the marker the review escapes the approval; without an approval the
  spawn is blocked. One approval buys one review, so a second run needs a new
  answer from the user.

  After that line, write the reviewer brief:

  - the worktree, the branch, the base and the range, from the brief;
  - the commits to review;
  - the rule files the brief lists, to read first and in that order. The first
    file that states a review method is the rulebook: its dimensions, its
    verification rules and its report shape bind the reviewer. Where no file
    states a method, the reviewer judges the correctness and the soundness of
    the change, runs no build and no test, and reports its findings in
    Simplified Technical English, most severe first, each with the file and the
    line, the evidence, and the expected behaviour;
  - the sources of the claim: the merge request description and its
    discussion, every issue they name, and the design document of each touched
    subsystem. Commit messages are not a source of the claim. When `$1` gives a
    reading of the claim, pass it as the claim;
  - the instruction to stop and return the readings when the claim stays
    ambiguous, before it reads the diff;
  - what it never does: a write to the repository, a commit, a stash, a
    `glab` write, a global install, a push. Read-only `glab … view` is allowed.
    The rulebook says whether the harness runs; where the rulebook allows a
    temporary test, the reviewer removes it and leaves `git status` as it found
    it.

  Say nothing about why you believe the change is right.

## 5. The answer

Relay the report as the sub-agent wrote it, in its structure. Do not soften
it, and do not argue with it. Apply a fix only where the user asks for one.

When the sub-agent returned the readings of an ambiguous claim, list them and
ask the user which one holds. The user then runs `/deep-review <the reading>`,
which carries that reading into the brief of the next run.
