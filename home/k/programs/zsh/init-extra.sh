### start zsh.initExtras

autoload -Uz run-help
(( ${+aliases[run-help]} )) && unalias run-help
alias help=run-help

# let batman command autocomplete like man
compdef batman=man

export EDITOR=nvim
export PATH=$(realpath ~/bin):$PATH
### end zsh.initExtras
