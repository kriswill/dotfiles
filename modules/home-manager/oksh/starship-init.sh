# starship-init-oksh.sh
#
# Initialize the Starship prompt under oksh (a portable fork of OpenBSD's
# pdksh-based ksh). The upstream `starship init bash` output relies on
# several bash-only features that oksh does not implement, so this file
# ports the moving parts to idiomatic pdksh.
#
# Usage:
#     . /path/to/starship-init-oksh.sh
# e.g. from ~/.kshrc.
#
# -----------------------------------------------------------------------------
# Differences from `starship init bash` (kept deliberately minimal):
#
#   1. No PROMPT_COMMAND, no PS0, no `trap ... DEBUG`.
#      pdksh/oksh support none of these. The bash init uses all three
#      to hook pre-command and pre-prompt callbacks. In oksh we instead
#      set PS1 to a single-quoted command substitution, which ksh
#      re-expands on every prompt draw; that is sufficient to run
#      starship fresh each prompt.
#
#   2. Command-duration timing removed.
#      Without a pre-exec hook we cannot record STARSHIP_START_TIME.
#      The `$duration` module in starship.toml will therefore never
#      render. SECONDS-based approximations are unreliable across
#      pipelines and subshells, so we drop the feature rather than
#      fake it.
#
#   3. Bash-only integrations dropped.
#      The ble.sh (https://github.com/akinomyoga/ble.sh) and
#      bash-preexec (https://github.com/rcaloras/bash-preexec) branches,
#      plus the BASH_VERSION / BASH_VERSINFO version gate, are removed.
#
#   4. PIPESTATUS support dropped.
#      pdksh/oksh does not expose PIPESTATUS. `--pipestatus` is omitted.
#
#   5. `local` -> `typeset`, and `f()` -> `function f { ... }`.
#      In pdksh, POSIX-style `f()` function definitions give variables
#      *global* scope even when declared with typeset. Using the ksh
#      `function` keyword is what enables function-local scope. See
#      the "Functions" section of the pdksh / OpenBSD ksh(1) manual:
#      https://man.openbsd.org/ksh.1
#
#   6. `shopt -s checkwinsize` removed.
#      oksh tracks $COLUMNS automatically on SIGWINCH; `shopt` is a
#      bash builtin and would error here.
#
#   7. Prompt non-printing markers translated.
#      With STARSHIP_SHELL=bash, starship wraps color escapes in the
#      literal two-character sequences `\[` and `\]` (bash readline's
#      convention). pdksh's line editor instead recognises the single
#      bytes 0x01 (SOH) and 0x02 (STX) for the same purpose. We pipe
#      the prompt through awk to translate, so oksh's line-wrap math
#      stays correct. See the "Prompting" section of ksh(1) and the
#      readline(3) PS1 conventions used by bash:
#      https://www.gnu.org/software/bash/manual/html_node/Controlling-the-Prompt.html
#
#   8. `\$` stripped to `$`.
#      Bash re-expands $ in PS1, so starship emits `\$` to protect a
#      literal dollar (e.g. the git_status stashed symbol, which
#      renders as e.g. `[$!+]`). ksh does not re-expand the output of
#      $(...) substitution in PS1 — parameter expansion happens once,
#      before the command-sub result is inserted — so a bare `$` in
#      the captured output stays literal. The bash-style `\` is then
#      just visible backslash noise. Strip it in the same awk pass.
#
#   9. `!` doubled to `!!`.
#      Per ksh(1), PS1 expansion runs in this order: parameter sub,
#      command sub, tilde, then history-designator substitution (`!`
#      → history number, `!!` → literal `!`). Because history sub
#      runs LAST — on the fully-assembled PS1, including the captured
#      output of $(_starship_prompt) — any bare `!` starship emits
#      (e.g. the git_status "modified" symbol, rendering as `[$!+]`)
#      gets replaced with the current command number, producing
#      garbage like `[$41+]`. Bash does not do this substitution, so
#      upstream starship has no reason to pre-escape. We escape
#      in-flight by doubling every `!` to `!!`, which ksh's history
#      pass collapses back to a single literal `!`.
#
# References:
#   * Starship shell init sources (upstream bash template):
#     https://github.com/starship/starship/blob/master/src/init/starship.bash
#   * Starship advanced configuration / custom shell notes:
#     https://starship.rs/advanced-config/
#   * oksh (portable OpenBSD ksh):
#     https://github.com/ibara/oksh
#   * OpenBSD ksh(1) manual:
#     https://man.openbsd.org/ksh.1
# -----------------------------------------------------------------------------

export STARSHIP_SHELL="bash"

# Resolve the starship binary once, at source time, via the user's PATH.
# `command -v` is POSIX and works identically across linux, macOS, BSDs,
# Nix, Homebrew, and hand-built installs — no hard-coded paths. If the
# binary is missing, fall through to a no-op PS1 so the shell is still
# usable and the user gets a clear diagnostic.
STARSHIP_BIN=$(command -v starship 2>/dev/null)
if [ -z "$STARSHIP_BIN" ]; then
    print -u2 "starship-init-oksh: 'starship' not found in PATH; prompt not initialised."
    return 0 2>/dev/null || exit 0
fi

# 16-digit session key. $RANDOM in pdksh returns 0-32767, so we concatenate
# five rolls, pad with zeros for the edge case of small values, and then
# trim to 16 characters. Mirrors the bash init's intent without relying on
# bash's ${var:offset:length} syntax (pdksh supports it, but cut is clearer).
STARSHIP_SESSION_KEY="$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM"
STARSHIP_SESSION_KEY="${STARSHIP_SESSION_KEY}0000000000000000"
STARSHIP_SESSION_KEY=$(printf %s "$STARSHIP_SESSION_KEY" | cut -c1-16)
export STARSHIP_SESSION_KEY

# Translate bash-style prompt non-printing markers (\[ \]) into the
# byte markers (0x01 0x02) that pdksh's line editor understands, strip
# the `\` from `\$` (bash's literal-dollar escape; ksh does not re-expand
# $ in a $(...) result, so the backslash is just visible noise), and
# double every `!` to `!!` so ksh's history-designator pass — which runs
# AFTER command substitution on the final PS1 — collapses it back to a
# literal `!` instead of replacing it with the command number.
function _starship_fix_markers {
    awk '{
        gsub(/\\\[/, "\001")
        gsub(/\\\]/, "\002")
        gsub(/\\\$/, "$")
        gsub(/!/,    "!!")
        print
    }'
}

# Build one prompt. Called by PS1 via command substitution, so $? inside
# reflects the exit status of the last interactive command.
function _starship_prompt {
    typeset _s=$? _j
    _j=$(jobs -p | wc -l | tr -d ' ')
    "$STARSHIP_BIN" prompt \
        --terminal-width="${COLUMNS:-80}" \
        --status="$_s" \
        --jobs="$_j" \
        --shlvl="${SHLVL:-1}" \
      | _starship_fix_markers
}

# Single quotes here are load-bearing: PS1 must be re-expanded on every
# prompt draw, not frozen at source time. Double quotes would freeze it.
PS1='$(_starship_prompt)'
PS2=$("$STARSHIP_BIN" prompt --continuation | _starship_fix_markers)
