# ~/.config/zsh/aliases.zsh — aliases and their completions. Sourced by .zshrc.

## ls -> eza; the ls-family aliases chain off it (zsh re-expands the
## first word, so e.g. `ll` -> `ls -lhF` -> `eza --icons --hyperlink -lhF`).
alias ls='eza --icons --hyperlink'
alias ld='ls -D'
alias ll='ls -lhF'
alias la='ls -lahF'
alias l='la'
alias t="ls -T -I '.git'"
alias cat='bat'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias man='batman'
alias ff='fastfetch'
alias gv='NVIM_APPNAME=gman nvim'
alias claude-yolo='claude --dangerously-skip-permissions'
alias cyolo='claude --dangerously-skip-permissions'

## Git (gco/gba chain off g the same way the ls family chains off ls).
alias g='git'
alias gco='g checkout'
alias gba='g branch -a'
alias lg='lazygit'

## man-page completion for bat-extras' `batman` (compinit ran in /etc/zshrc).
compdef batman=man
