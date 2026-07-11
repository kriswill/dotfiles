# ~/.config/zsh/functions.zsh — opt-in helper functions. Sourced by .zshrc.

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
