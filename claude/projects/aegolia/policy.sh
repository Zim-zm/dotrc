# The policy of the aegolia repository. Every value that names the project
# lives here; zim-paths.sh and zim-rules.sh source it and hold the mechanism.

ZIM_PROJECT=aegolia

ZIM_COMMIT_TYPES="feat fix refactor perf test doc style ci build revert wip"
ZIM_SUBJECT_MAX=100
ZIM_BODY_MAX=80
ZIM_SENTENCE_MAX=25

# A commit whose author date precedes this day keeps the style of its time.
ZIM_CONVENTIONAL_SINCE="2026-09-21"

zim_commit_type_table() {
  cat <<'TABLE'
feat      a capability the project did not have: a feature, an option, a supported reference form
fix       a wrong result, a crash or a wrong message, in behaviour already claimed
refactor  a code change with no change of any result: a rename, a move, an extraction, an inlining, a dead-code removal, a signature threaded through its call sites
perf      a speed or a memory gain with no change of any result
test      a test, a fixture of test_cases/ or a recording of test_samples/; it changes no production line
doc       documentation only: a document under docs/, a Markdown file, or a comment in code; it changes no code line
style     formatting only: a formatter run, whitespace, a line wrap; it renames nothing
ci        the pipeline: .gitlab-ci.yml, the runner images, the release scripts
build     the build, the dependencies and the repository tooling: Cargo.toml, package.json, the lockfiles, xtask, the hooks, the agent settings; build(deps): for a bump
revert    a hand-written revert; the body names the reverted commit
wip       a snapshot; it needs WIP=1 in the command and skips the other message rules
TABLE
}

# Pathspecs that exclude non-production files from a diff.
ZIM_NON_PRODUCTION=(
  ':!tests/*'
  ':!client/tests/*'
  ':!test_cases/*'
  ':!test_samples/*'
  ':!docs/*'
  ':!*.md'
)

# The paths that record a result of the program: a committed fixture carries
# the refs the pipeline produced for its text.
ZIM_RECORDED_OUTPUT=(
  'test_cases/*.json'
)

# The paths whose text a reviewer never needs: the diff file carries their
# stat line only, and the deep review counts them as data. A binary file is
# opaque whatever its path.
ZIM_OPAQUE=(
  'test_samples/*'
  'data/*.json'
  'Cargo.lock'
  'package-lock.json'
)

# The last-resort review base, when no config key, no branch tip below HEAD and
# no integration branch answers.
ZIM_BASE_DEFAULT=origin/main

# The rule files the style reviewer reads, in order, relative to the worktree
# root. The general file comes first; the project file adds and never relaxes.
ZIM_RULE_FILES=(RULES.md COMMITS.md)

# The rule files the deep review brief names, relative to the worktree root.
ZIM_DEEP_REVIEW_RULES=(REVIEW.md AGENTS.md CONTEXT.md)

# The skills the installer links into the project.
ZIM_SKILLS="check-style deep-review"
