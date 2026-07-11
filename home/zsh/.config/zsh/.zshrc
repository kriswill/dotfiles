# ~/.config/zsh/.zshrc — Kris' interactive zsh config (ZDOTDIR = ~/.config/zsh).
#
# Deployed by the stow tree (home/zsh) via each OS's dotfiles-stow module
# (modules/darwin/dotfiles-stow.nix, modules/nixos/dotfiles-stow.nix). The
# system /etc/zshenv sets ZDOTDIR here (each OS's zsh module), and /etc/zshrc
# provides compinit, autosuggestions, and syntax highlighting. This file runs
# last, so it gets the final word on aliases and the prompt.

## History — the system /etc/zshrc already set HISTSIZE/SAVEHIST/HISTFILE
## (~/.local/state/zsh/history); raise the limits here.
HISTSIZE=100000
# shellcheck disable=SC2034 # SAVEHIST is a zsh parameter; shellcheck only knows bash
SAVEHIST=10000000

## Options
setopt interactivecomments # allow comments on the command line
setopt AUTO_CD             # bare `dir/` cd's into it

## Editor — used by edit-command-line below (EDITOR/MANPAGER are set
## system-wide by each OS's neovim module).
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

## man-page completion for bat-extras' `batman`.
compdef batman=man

## yazi — `y` wraps yazi so quitting (q) cd's the shell into yazi's last
## directory; quit with Q to skip the cd. Quitting from search results yields
## a virtual `search://<keyword>//<dir>` URL instead of a path — recover the
## real dir, and never cd to anything that isn't one.
## POSIX-compatible: no local/[[ ]]/read -d, must run in the current shell
## (it cd's), so scope variables by prefix and unset them on the way out.
y() {
  y_tmp=$(mktemp "${TMPDIR:-/tmp}/yazi-cwd.XXXXXX") || return 1
  yazi "$@" --cwd-file="$y_tmp"
  IFS= read -r y_cwd < "$y_tmp" || :
  rm -f -- "$y_tmp"
  case $y_cwd in
    search://*) y_cwd="/${y_cwd#search://*//}" ;;
  esac
  if [ -n "$y_cwd" ] && [ "$y_cwd" != "$PWD" ] && [ -d "$y_cwd" ]; then
    cd -- "$y_cwd"
  fi
  unset y_tmp y_cwd
}

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

## Darwin-specific (guarded so this file stays portable across hosts and OSes).
## determinate-nixd's `completion zsh` takes ~300ms per shell to emit the same
## static script, so cache it and refresh only when the binary changes.
if command -v determinate-nixd > /dev/null; then
  _dnd_bin="$(command -v determinate-nixd)"
  _dnd_cache="$ZDOTDIR/.determinate-nixd-completion.zsh"
  if [[ ! -f $_dnd_cache || $_dnd_bin -nt $_dnd_cache ]]; then
    "$_dnd_bin" completion zsh > "$_dnd_cache"
  fi
  source "$_dnd_cache"
  unset _dnd_bin _dnd_cache
fi
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

## PATH: bun globals and user-local bins, plus the persistent system-profile path
## as a fallback. On macOS, set-environment puts /run/current-system/sw/bin on
## PATH, but that symlink lives in volatile /run and is only recreated by the
## activate-system daemon once the FileVault-encrypted /nix volume mounts at login
## — so a terminal opened in that brief post-login window can't find
## starship/zoxide/direnv/etc. /nix/var/nix/profiles/system/sw/bin is the same
## store path and resolves the moment /nix is mounted, independent of /run.
## (Harmless on NixOS, where /run/current-system is reliable.)
export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH:/nix/var/nix/profiles/system/sw/bin"

## Prompt — starship (each OS's zsh module disables the default `prompt suse`
## so this wins cleanly).
eval "$(starship init zsh)"

## Smart cd — zoxide, jump with `j <dir>`.
eval "$(zoxide init zsh --cmd j)"

## direnv — per-directory envs (guarded: not provisioned on every host yet).
command -v direnv > /dev/null && eval "$(direnv hook zsh)"

## fd/tree come from the user package set (each OS's user-packages module).
export FZF_DEFAULT_COMMAND="fd --type f"
export FZF_DEFAULT_OPTS="--height 40% --prompt ⟫"
export FZF_ALT_C_COMMAND="fd --type d"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -200'"

## fzf keybindings + completion (binds Ctrl-R; hstr below must come AFTER so its Ctrl-R wins).
command -v fzf > /dev/null && source <(fzf --zsh)

## hstr — fuzzy history picker on Ctrl-R.
export HSTR_CONFIG=hicolor
setopt histignorespace
bindkey -s "\C-r" "\C-a hstr -- \C-j"

## claude-account-selector wrapper — generated by its darwin module on
## hosts that enable it; absent elsewhere.
[ -f "$ZDOTDIR/claude-account-selector.zsh" ] && source "$ZDOTDIR/claude-account-selector.zsh"
