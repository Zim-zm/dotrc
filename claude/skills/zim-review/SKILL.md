---
name: zim-review
description: Run the commit-style review of the current branch now, in a clean sub-agent that sees only the diff and the rules. Use when the user asks for a style review, a commit review, or a check that the commits follow the commit rules, and before an in-depth review or a merge request.
---

# On-demand commit style review

This runs the review that the `Stop` hook runs, but now, and whatever the state
of the tree.

1. Run the gate:

   ```
   ~/.claude/zim/zim-review-gate.sh "$PWD" false --force
   ```

2. When the first line starts with `SKIP`, report that line and stop. The gate
   skips for a real reason only: the directory is no worktree, the base does not
   exist, or the branch adds no commit above the base.

3. Otherwise spawn exactly one sub-agent with the `Agent` tool:

   - `subagent_type`: `general-purpose`
   - `model`: `sonnet`
   - `description`: `Commit style review`
   - `prompt`: the complete output of the gate, copied verbatim.

   The payload holds the procedure, the rules, the commit types, the commit list
   with its mechanical verdicts, and the path of the diff file. Add nothing to
   it. Summarize nothing. You wrote the code, so your context holds the excuses
   that a review must not accept.

4. Report the answer of the sub-agent:

   - `{"ok": true}`: record the pass, then say that the review found nothing:

     ```
     ~/.claude/zim/zim-review-gate.sh "$PWD" false --record-pass
     ```

   - `{"ok": false, "reason": ...}`: give the findings as the sub-agent wrote
     them, grouped by commit. Record nothing. Do not soften them. Do not argue
     with them. Fix nothing unless the user asks for it.

The record gates the deep audit of the `zim-audit` skill, which reads the type
of each commit. Only this review checks that the type fits the diff.

Never run the review in this session, and never send it to a second agent.
