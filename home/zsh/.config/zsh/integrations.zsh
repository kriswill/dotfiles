# ~/.config/zsh/integrations.zsh — third-party tool hooks. Sourced by .zshrc
# after the PATH export so the tools are findable. Internal order matters:
# fzf binds Ctrl-R, and atuin must come AFTER so its Ctrl-R/Up-arrow win.

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

## fzf keybindings + completion (binds Ctrl-R; atuin below must come AFTER so its Ctrl-R/Up-arrow win).
command -v fzf > /dev/null && source <(fzf --zsh)

## atuin — fuzzy history search (Ctrl-R + Up-arrow), config at ~/.config/atuin/config.toml.
eval "$(atuin init zsh)"
