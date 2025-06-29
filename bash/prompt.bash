__prompt_command() {
    local _exit="$?"

    # Colors
    local RCol='\[\e[0m\]'

    local Red='\[\e[0;31m\]'
    local Gre='\[\e[0;32m\]'
    local BYel='\[\e[1;33m\]'
    local BBlu='\[\e[1;34m\]'
    local Pur='\[\e[0;35m\]'


    # Start the prompt from scratch
    PS1=""

    # Bracket around the first line to improve readability
    PS1="${BBlu}[${RCol} "

    # Display time
    PS1+="\t "

    # Add red if exit code non 0.
    if [ $_exit != 0 ]; then
        PS1+="res:${Red}${_exit}${RCol} "
    else
        PS1+="res:${Gre}${_exit}${RCol} "
    fi

    # git information
    local inside_work_tree
    inside_work_tree="$(git rev-parse --is-inside-work-tree 2>/dev/null || echo "false")"
    if [[ "$inside_work_tree" == "true" ]]; then
        local _git_branch
        _git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
        if test -n "${_git_branch:-}"; then
            if test -z "$(git status --untracked-files=no --porcelain)"; then
                PS1+="git:'${Gre}$_git_branch${RCol}' "
            else
                PS1+="git:'${Red}$_git_branch${RCol}' "
            fi
        fi
    fi

    # TIS installation
    if test -n "${WORK_CONFIG:-}"; then
        source "${WORK_CONFIG}/bash/prompt.bash"
    fi

    PS1+="${BBlu}]${RCol}\n"

    # Put some emotions in the prompt.
    # PS1+=" 👺 "

    # User, hostname and path.
    # PS1+="${Gre}\u@\H${RCol}:${BBlu}\w${RCol}\$ "
    PS1+="${Gre}\u@\H${RCol} 👺 ${BBlu}\w${RCol}\$ "
}

PROMPT_COMMAND=__prompt_command
