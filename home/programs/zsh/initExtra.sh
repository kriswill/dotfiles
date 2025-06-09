## ZSH initExtra

setopt interactivecomments # allow comments on the command-line
setopt AUTO_CD
# enable ctrl-x-e to edit with Neovim
autoload -U edit-command-line
zle -N edit-command-line
# Emacs style
# bindkey '^xe' edit-command-line
# bindkey '^x^e' edit-command-line
# Vi style
bindkey -M vicmd v edit-command-line
# add red background to stderr
autoload -Uz add-zle-hook-widget

eval "$(/opt/homebrew/bin/brew shellenv)"

function stderred() {
    RED_BG=$'\e[41m'
    RESET=$'\e[0m'

    function colorize_stderr() {
        while IFS= read -r line; do
            printf "%s%s%s\n" "$RED_BG" "$line" "$RESET"
        done
    }

    exec 2> >(colorize_stderr)
}

# man pages autocomplete for batman
compdef batman=man
