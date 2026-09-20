# Coding and commit style

These rules apply to every project. They are the general file; a project file
adds constraints on top of them and never relaxes them. Where the project file
is stricter, follow the stricter rule; where it is silent, these rules hold.
The project file names what only the project can name: the artefacts that
record an output, the print form of its toolchain, the file header, the paths
that are not production code. If a project rule genuinely contradicts one here,
say so and ask the user rather than picking a side.

## Commits

**Atomic.** Exactly one logical change per commit: one fix, one feature slice,
one refactor, one rename, one function extraction, one plumbing change. Never
mixed — not a fix plus a refactor, not two unrelated refactors. A task that
naturally produces several changes becomes several commits.

**Green.** Each commit builds and passes its tests on its own.

**Ordering.** For each fix or feature: commit each refactor the change needs,
then the fix or feature itself, then move on to the next one. Do not batch
refactoring across several upcoming changes. For a fix in a project that has a
test suite, commit the test that reproduces the defect between the last refactor
and the fix. Nothing else separates the two. Its recorded output holds the
wrong result, so the commit stays green, and the fix commit changes the
recording. A cleanup that the change makes possible follows the change.

**The evidence of a defect.** When the fix changes what a generator emits, and
the toolchain can print that artefact, the test prints it. Filter the print to
the smallest set of functions that shows the defect. The test recording then
holds the wrong artefact, and the fix recording holds the right one. A `test:`
commit right after the fix removes the print and the filter. The project file
states the print form of the toolchain, or that the toolchain has none.

**Before committing, check:** does this diff address exactly one concern? If
not, split it. If a non-refactor commit exceeds 100 lines of production code
(tests do not count), look again for a split. If you genuinely cannot split it,
ask the user how it should be split rather than committing it as-is.

**Messages.** Brief, and never a rephrasing of the code. Write no body clause
that a reader can derive from the diff. One or two sentences is usually enough.

**Simplified Technical English.** The message follows ASD-STE100:

- one idea in a sentence, and 25 words or fewer in it;
- 6 sentences or fewer in a paragraph;
- the active voice, and the sentence names the agent of the action;
- a simple tense, and the present where it fits;
- one word for one meaning, and the same word for the same thing;
- the short common word, not the long one: "use", not "utilize"; "need", not
  "require"; "before", not "prior to"; "about", not "approximately"; "start",
  not "commence"; "help", not "assist"; "but", not "however"; "so", not "thus";
- no idiom, no slang, no metaphor;
- no noun made from a verb: write "the guard reads the message", not "the guard
  does a read of the message";
- no `-ing` form as a noun or an adjective;
- 3 words or fewer in a noun cluster;
- the articles stay: "the file", not "file";
- a code identifier, a path and a command name stay as they are.

**Subject.** Write `type(scope): description.` The type is mandatory, the scope
is optional, and a `!` before the colon marks a breaking change. The description
starts with a lowercase letter and ends with a period. The whole subject holds
100 characters or fewer. The policy file of the project holds the accepted
types and states what each one covers; the commit guard shows that table at
commit time, and the reviewer receives it in the payload.

**Body.** A blank line separates the subject and the body. Each body line holds
80 characters or fewer. When a result-preserving commit changes an output, a
recording or a message, an `Output-justification:` line says why the results
are the same.

**Footers.** A footer opens with a capitalised word and a colon, and it sits at
the end of the message. It escapes the sentence and the line rules, so it can
run long.

- `Assisted-by:` — always, exactly one, with the assistant your harness names.
- `Atomic:` — over 100 production lines, and the commit holds one concern.
- `Mechanical:` — over 100 production lines, and the diff is a rename, a move or
  a sweep. A `feat:`, a `fix:` or a `perf:` commit never carries it: the sweep
  is its own `refactor:` commit before it.
- `Output-justification:` — a `refactor:`, a `style:` or a `perf:` commit
  changes a recording, an output or a message. It says why the results are the
  same.
- `Closes: #9152` — the commit closes the ticket.
- `Related: #9152` — the ticket in every other case.
- Never `Co-Authored-By:`.

## Merge requests

**Confirmation.** Never create or update a merge request without an explicit
confirmation from the user. Show the complete content that you will send: the
title, the description, the target branch, the labels, and the quick actions.
Wait for the user to read it and to approve it. The user approves the text that
reaches the reviewers. You do not.

The project template owns the structure. Fill its sections. Do not invent a
different structure. These rules control what you write inside it.

**Voice.** The same as a commit message: Simplified Technical English, one idea
per sentence, the active voice, one word for one meaning.

**Length.** One sentence says what the MR does. Add one or two sentences of
"why" only when the ticket does not give it.

**Ticket.** Always name the ticket in the relations block. Use `Closes:` when
the MR closes it. Use `Related:` in the other cases.

**Stacked MRs.** When this MR sits on top of another one, link the previous MR
first, above every other section.

**Order.** Use this order:

1. the link to the previous MR, when the MR is stacked;
2. the relations block with the ticket;
3. one sentence on what the MR does;
4. the "why", when the ticket does not give it;
5. the review questions.

When no template applies, write these items only. Do not invent a checklist.

**Review questions.** Report a decision here only when all three conditions
hold:

- You could not verify the hypothesis behind the decision.
- The code must change if the hypothesis is false.
- The reviewer can judge it. You cannot.

Write each question as one sentence. Write 3 questions or fewer. When you find
more than 3, the MR is too large or too uncertain. Ask the user before you open
it.

**Checklists.** A checklist item and a review question never overlap. You can
verify a checklist item yourself, so run it and report the result. You cannot
verify a review question, so the reviewer answers it. Never convert a check that
you skipped into a review question. Run the check.

**Everything else.** Put a decision that explains the code permanently in the
commit message. Put a risk that no reviewer can judge in an issue. Leave a
verified fact out.

## Code

**Single source of truth.** Classification, decision logic, and any
domain-oriented abstraction must exist in exactly one place — as must anything
correctness-relevant. Size is not a factor: three duplicated lines of decision
logic are as wrong as thirty. When clean extraction is blocked, that is a signal
that a refactor is required — ask the user; if you can see a narrower helper,
propose it and let them decide.

**Naming.** Follow the codebase's existing style for length and abbreviations.
Names must be self-documenting, functions especially. Function, parameter, and
variable names are part of the documentation.

**Name-quality signals.** A wrapper needing more than two lines of documentation
beyond its name is a sign of a bad wrapper. A fundamental function of the
project needing more than seven lines beyond its name is a sign of an improper
abstraction. Treat both as design problems, not documentation problems.

**Comments.** A comment signals unclear code. When a piece of code seems to
deserve one, rephrase the code until it does not. If you cannot, or the comment
concerns something implicit that the code cannot show, ask the user for guidance
rather than writing it yourself.

**Function documentation.** Brief — rarely more than two sentences. Needing more
usually means the names are not descriptive enough; fix the names.

**Punctuation.** Comments and documentation sentences start with a capital
letter and end with a period.

**File and module headers.** The project file states the file header, when the
project has one. Anything else is optional.
