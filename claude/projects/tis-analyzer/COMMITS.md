# COMMITS.md

Project clarifications to `RULES.md` for tis-analyzer. `RULES.md` states the
principle; this file names the artefacts. It adds to the general file and never
relaxes it.

## The recorded output

An oracle file records the output of a test: `oracle/`, `*/oracle/*` and
`*.oracle`. The `test:` commit that reproduces a defect records the wrong
oracle; the `fix:` commit changes it. A `refactor:`, a `style:` or a `perf:`
commit that changes an oracle carries an `Output-justification:` line.

## The evidence of a defect

The toolchain prints the artefact that a fix changes. The form is
`STDOPT: +"-val -print -print-filter <the functions>"` in the `run.config`
header of the test. The filter names the smallest set of functions that shows
the defect.

## Production lines

The size tripwire counts the changed lines outside `tests/`, `oracle/`, the
`doc/` directories and every Markdown or reStructuredText file.

## File headers

A source file starts with the license header. Anything else is optional.
