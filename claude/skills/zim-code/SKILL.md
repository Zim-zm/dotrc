---
name: zim-code
description: The user's standing rules for how code is written, how commits are structured, and how merge requests are described. Use when writing code destined for the repository, choosing names, deciding whether to comment, splitting work into commits, writing commit messages, or opening and describing a merge request. Not for throwaway repros, debugging scratch, or instrumentation.
---

# Coding and commit style

The rules live in two files at the worktree root. Read both, in this order,
before you write code, split work into commits, write a message, or describe a
merge request:

1. `RULES.md` — the general file, the same in every project.
2. `COMMITS.md` — the project file. It names the artefacts of this project and
   adds to the general file; it never relaxes it.

The commit guard shows the commit types at commit time. Where the two files
genuinely contradict each other, say so and ask the user rather than picking a
side.
