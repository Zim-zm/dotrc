# The policy of the tis-analyzer repository. Every value that names the project
# lives here; zim-paths.sh and zim-rules.sh source it and hold the mechanism.

ZIM_PROJECT=tis-analyzer

ZIM_COMMIT_TYPES="feat fix refactor perf test doc style ci build revert wip"
ZIM_SUBJECT_MAX=100
ZIM_BODY_MAX=80
ZIM_SENTENCE_MAX=25

# A commit whose author date precedes this day keeps the style of its time.
ZIM_CONVENTIONAL_SINCE="2026-09-08"

zim_commit_type_table() {
  cat <<'TABLE'
feat      a capability the project did not have: a feature, an option, a supported construct
fix       a wrong result, a crash or a wrong message, in behaviour already claimed
refactor  a code change with no change of any result, such as a rename, a move, an extraction, an inlining or a dead-code removal
perf      a speed or a memory gain with no change of any result
test      a test, a run.config or an oracle; it changes no production line
doc       documentation only: a document, or a comment in code; it changes no code line
style     formatting only: a formatter run, whitespace, a line wrap; it renames nothing
ci        the pipeline: .gitlab-ci.yml, the runner images, the release scripts
build     the build and the dependencies: dune, opam, the Makefile, build(deps): for a bump
revert    a hand-written revert; the body names the reverted commit
wip       a snapshot; it needs WIP=1 in the command and skips the other message rules
TABLE
}

# Pathspecs that exclude non-production files from a diff.
ZIM_NON_PRODUCTION=(
  ':!*/tests/*'
  ':!tests/*'
  ':!*/oracle/*'
  ':!*.oracle'
  ':!*doc/*'
  ':!*.md'
  ':!*.rst'
)

# The paths that record a result of the program.
ZIM_RECORDED_OUTPUT=(
  'oracle/*'
  '*/oracle/*'
  '*.oracle'
)

# The last-resort review base, when no config key, no branch tip below HEAD and
# no integration branch answers.
ZIM_BASE_DEFAULT=origin/master

# The rule files the style reviewer reads, in order, relative to the worktree
# root. The general file comes first; the project file adds and never relaxes.
ZIM_RULE_FILES=(RULES.md COMMITS.md)

# The rule files the deep review brief names, relative to the worktree root.
ZIM_DEEP_REVIEW_RULES=(tis-analyzer/rust/CLAUDE.md RULES.md COMMITS.md)

# The skills the installer links into the project.
ZIM_SKILLS="zim-code check-style deep-review"
