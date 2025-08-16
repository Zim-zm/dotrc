# Generic aliases.
alias ppwd='cd `pwd -P`'
alias vim=nvim

# Clang aliases 'cuz I use them a lot.
alias ast++='clang++ -std=c++11 -Xclang -ast-dump -fsyntax-only'
alias record='clang++ -std=c++11 -Xclang -fdump-record-layouts'
alias vtable='clang++ -std=c++11 -Xclang -fdump-vtable-layouts'

# Git stuff
alias wls='git worktree list'

# If at work, load the work-related aliases.
if [[ -n "${WORK_CONFIG:-}" ]]; then
    source "$WORK_CONFIG/bash/alias.bash"
fi
