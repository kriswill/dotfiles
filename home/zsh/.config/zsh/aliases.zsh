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

## `open` everywhere: macOS has it natively; Linux gets xdg-open
## (the xdg-open-journal wrapper diverts tty stdout to the journal).
[[ $OSTYPE == linux* ]] && open() { xdg-open "$@" }

## Git (gco/gba chain off g the same way the ls family chains off ls).
alias g='git'
alias gco='g checkout'
alias gba='g branch -a'
alias lg='lazygit'

## rtk against the work-account stats DB (pairs with RTK_DB_PATH in
## ~/.claude-work/settings.json; plain `rtk` stays on the default/me DB).
alias rtk-work='RTK_DB_PATH=$HOME/.local/share/rtk/history-work.db rtk'
alias rtkw='rtk-work'

## Pull the X11/XWayland clipboard into the Wayland one — Hyprland fails to
## bridge the CLIPBOARD selection from XWayland apps (WoW under Proton), so a
## copy in-game lands only in the X clipboard until pulled across.
## A function (not an alias) so non-interactive shells like Claude Code's
## Bash tool can call it; echoes the pulled text so the caller sees it.
[[ $OSTYPE == linux* ]] && wowclip() {
  local text
  text=$(nix shell nixpkgs#xclip -c xclip -o -selection clipboard -d :0) || return $?
  printf '%s' "$text" | wl-copy
  printf '%s\n' "$text"
}

## man-page completion for bat-extras' `batman` (compinit ran in /etc/zshrc).
compdef batman=man
