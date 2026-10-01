# Readline key bindings (emacs mode).

# Alt+Shift+I: abandon the current line as Ctrl+C would, then go up one
# directory.
#
# Readline erases the input line before running a bind -x command, so
# __cd_up reprints it (last prompt line, typed text, then ^C) before the
# directory changes.
__cd_up() {
    local prompt="${PS1@P}"
    prompt="${prompt##*$'\n'}"
    prompt="${prompt//[$'\001\002']/}"
    printf '%s%s^C\n' "$prompt" "$READLINE_LINE"
    READLINE_LINE=""
    READLINE_POINT=0
    __cd_up_redrawn=1
    cd .. || return
}

# After __cd_up returns, readline redraws the stale prompt line below the
# reprinted one. Erase it before the new prompt is printed in its place.
#
# This file must be sourced after prompt.bash: prompt.bash assigns
# PROMPT_COMMAND outright, which would drop this hook.
__cd_up_erase_stale_prompt() {
    if [[ -n "${__cd_up_redrawn:-}" ]]; then
        printf '\e[1A\e[2K'
        unset __cd_up_redrawn
    fi
}
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}__cd_up_erase_stale_prompt"

# bind -x cannot redraw the prompt, so Alt+Shift+I is a macro: run __cd_up
# through an otherwise unused key, then accept the now-empty line so that
# PROMPT_COMMAND rebuilds the prompt without adding a history entry.
bind -x '"\C-x\C-]": __cd_up'
bind '"\eI": "\C-x\C-]\C-m"'
