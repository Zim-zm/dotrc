# Allow ** as globbing
shopt -s globstar

# Correct minor spelling errors when doing cd.
shopt -s cdspell

# Try to save multi-line commands in the same history entry.
shopt -s cmdhist

# Append to history file instead of overwriting it.
shopt -s histappend

export PATH="$HOME/local/bin:$PATH"

# More history
export HISTSIZE=20000
export HISTFILESIZE=20000
