# ~/.config/zsh/.zshrc — Kris' interactive zsh config (ZDOTDIR = ~/.config/zsh).
#
# Ported from the cross-host home-manager zsh module (dotfiles `main` branch).
# nebula runs no home-manager: the NixOS module (nixosModules/default/zsh.nix)
# enables zsh, installs the supporting tools, and points ZDOTDIR here. This file
# is the editable, stow-managed user rc; it runs last, after /etc/zshrc, so it
# gets the final word on aliases and the prompt.

## History — keep more than the system default. HISTFILE is set to
## ~/.local/state/zsh/history by the NixOS module (XDG state, not $HOME).
HISTSIZE=100000
SAVEHIST=10000000

## Options
setopt interactivecomments # allow comments on the command line
setopt AUTO_CD             # bare `dir/` cd's into it

## Editor — used by edit-command-line below (EDITOR=nvim is set system-wide).
export VISUAL=nvim

## Vi-mode + edit-command-line: press `v` in command mode to edit the current
## line in $VISUAL.
set -o vi
autoload -U edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

## Aliases. ls -> eza; the ls-family aliases chain off it (zsh re-expands the
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
alias ff='fastfetch'
alias gv='NVIM_APPNAME=gman nvim'
alias claude-yolo='claude --dangerously-skip-permissions'
alias cyolo='claude --dangerously-skip-permissions'

## man-page completion for bat-extras' `batman`.
compdef batman=man

## Red background on stderr. Defined but not enabled by default — run `stderred`
## to turn it on in the current shell.
function stderred() {
  local RED_BG=$'\e[41m' RESET=$'\e[0m'
  function colorize_stderr() {
    while IFS= read -r line; do
      printf '%s%s%s\n' "$RED_BG" "$line" "$RESET"
    done
  }
  exec 2> >(colorize_stderr)
}

## PATH: bun globals and user-local bins.
export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"

## Prompt — starship (replaces the NixOS default `prompt suse`, which zsh.nix
## disables so this wins cleanly).
eval "$(starship init zsh)"

## Smart cd — zoxide, jump with `j <dir>` (mirrors the main-branch setup).
eval "$(zoxide init zsh --cmd j)"

## hstr — fuzzy history picker on Ctrl-R.
export HSTR_CONFIG=hicolor
setopt histignorespace
bindkey -s "\C-r" "\C-a hstr -- \C-j"
