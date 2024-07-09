### start zsh.initExtras

autoload -Uz run-help
(( ${+aliases[run-help]} )) && unalias run-help
alias help=run-help

# let batman command autocomplete like man
compdef batman=man

### end zsh.initExtras