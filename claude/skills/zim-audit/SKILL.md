---
name: zim-audit
description: Deep review of a branch, or of one named commit, in a clean sub-agent - correctness and soundness, not style. Use when an implementation task ends, or when the user asks for an in-depth review, an audit, or a self-review of a branch or a commit. It always asks the user before it spends anything.
---

# Deep audit

The style review judges the form of a commit. This judges the change itself. It
costs minutes and millions of tokens, so the user approves every run.

`$1` names what to audit: a commit, a range, or nothing.

## Two ways in

**A named target** — `/zim-audit f2aa416c` or `/zim-audit base..HEAD`. Audit
exactly what the user names, whatever its type, and whatever any test says. Go
straight to step 3. The user's request overrides both filters below, and the
commit type decides nothing here, so the style pass is not needed.

**No argument** — audit the branch. Run step 1 and step 2 first.

## 1. The style review passes first

```
~/.claude/zim/zim-review-gate.sh "$PWD" false --check-pass
```

- `PASSED`: go to step 2.
- `NOT PASSED`: invoke the `zim-review` skill, and return here when it finds
  nothing. Never skip this step. Step 2 reads the type of each commit, and only
  the style review checks that the type fits the diff. A commit named
  `refactor:` that changes behaviour would escape the audit.

## 2. A pure refactor needs no audit

```
source ~/.claude/zim/zim-paths.sh
source ~/.claude/zim/zim-rules.sh
zim_is_pure_refactor <worktree> <commit>
```

The test holds when the commit is a `refactor:` or a `style:` commit **and**
changes no test, no oracle and no document. Such a commit changes nothing that
the project records, so the style review covers it alone.

Run the test on each commit above the review base. When every commit passes,
report that and stop. Spawn no agent, and ask nothing.

## 3. Ask the user, always

Report, in a few lines:

- each commit the audit would cover: the short sha, the subject, and the size of
  its diff from `git show --stat`;
- the model: Opus 5;
- the one cost measurement on record: 17.8 minutes and 11.5 M input tokens for
  one commit of a large OCaml pass, on 2026-09-08.

Then ask with `AskUserQuestion`. Offer three answers: audit every commit listed,
audit a part of them, or skip the audit. Spawn nothing before the answer.

When the user skips, drop the subject. Do not propose the same audit again.

When the user approves, record it:

```
~/.claude/zim/zim-review-gate.sh "$PWD" false --approve-audit "<the commits>"
```

## 4. One sub-agent for the whole target

Spawn exactly one agent with the `Agent` tool:

- `subagent_type`: `general-purpose`
- `model`: `opus`
- `prompt`: its **first line is `ZIM-AUDIT`**, alone. `zim-audit-guard.sh` reads
  that marker, checks the approval, and consumes it. Without the marker the
  audit escapes the approval; without an approval the spawn is blocked. One
  approval buys one audit, so a second run needs a new answer from the user.

  After that line, write the reviewer brief: the worktree, the branch, the base,
  the commits to audit, and the rule files to read
  (`tis-analyzer/rust/CLAUDE.md` where it exists, and
  `~/.claude/skills/zim-code/SKILL.md`). Forbid a build, a test run, and every
  write. Give the domain context the reviewer needs to judge the change. Say
  nothing about why you believe the change is right.

Report its findings, and apply a fix only where the user asks for one.
