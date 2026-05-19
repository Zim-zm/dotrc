#!/bin/bash
# hl - highlight words in stdin
# Usage: some_command | hl foo bar baz

hl() {
    if [ $# -eq 0 ]; then
        echo "Usage: command | hl word1 [word2 ...]" >&2
        return 1
    fi

    local pattern
    pattern=$(printf '%s|' "$@")
    pattern="^|${pattern%|}"

    grep --color=always -E "$pattern"
}
