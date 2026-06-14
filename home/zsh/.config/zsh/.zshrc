## History — keep more than the system default. HISTFILE is set to
## ~/.local/state/zsh/history by the NixOS module (XDG state, not $HOME).
HISTSIZE=100000
# shellcheck disable=SC2034 # SAVEHIST is a zsh parameter; shellcheck only knows bash
SAVEHIST=10000000

## hstr — fuzzy history picker on Ctrl-R.
export HSTR_CONFIG=hicolor
bindkey -s "\C-r" "\C-a hstr -- \C-j"
setopt histignorespace

setopt interactivecomments # allow comments on the command line
setopt AUTO_CD             # bare `dir/` cd's into it

export VISUAL=nvim

## Vi-mode + edit-command-line: press `v` in command mode to edit the current
## line in $VISUAL.
set -o vi
autoload -U edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

alias ls='eza --icons --hyperlink'
alias ld='ls -D'
alias ll='ls -lhF'
alias la='ls -lahF'
alias l='la'
alias lg='lazygit'
alias t="ls -T -I '.git'"
alias cat='bat'
alias ..='cd ..'
alias ...='cd ../..'
alias ff='fastfetch'

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

export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"

## Prompt — starship (replaces the NixOS default `prompt suse`, which zsh.nix
## disables so this wins cleanly).
eval "$(starship init zsh)"

## Smart cd — zoxide, jump with `j <dir>`
eval "$(zoxide init zsh --cmd j)"
