# atuin (shell history)

Ctrl-R fuzzy history search, replacing `hstr` (removed 2026-07-18).
Sync-enabled via an Atuin Hub account (see Sync below) — history is meant to
follow across hosts, not stay local. Maintained for Claude's use: keep it
accurate, and record real gotchas in **Learned behaviours & workarounds** at
the bottom.

## Version & state (verified 2026-07-18)

- Package: `pkgs.atuin` 18.17.0, installed via `environment.systemPackages`
  in `modules/darwin/zsh.nix` / `modules/nixos/zsh.nix` (same list that used
  to carry `hstr`).
- Shell hook: `eval "$(atuin init zsh)"` in
  `home/zsh/.config/zsh/integrations.zsh`, sourced after `fzf --zsh` — atuin
  must come last so its Ctrl-R (and Up-arrow) bindings win over fzf's.
- Config: `home/atuin/.config/atuin/config.toml` (stow package, deployed on
  both OSes like every other `home/` dir — see the
  [stow tree pattern](../knowledge/patterns/stow-tree.md)).
- History db: `~/.local/share/atuin/history.db` (SQLite, atuin-managed,
  separate from zsh's own `~/.local/state/zsh/history`).

## Config (`home/atuin/.config/atuin/config.toml`)

```toml
auto_sync = true
update_check = false
history_filter = ["^\\s", "^cd\\b", "^j\\b"]
```

- `auto_sync = true` — sync history through the linked Atuin Hub account
  (see Sync below).
- `update_check = false` — package updates come from the flake, not a
  self-updater, so the daily version-check network call is dead weight.
- `history_filter = ["^\\s", "^cd\\b", "^j\\b"]` — atuin hooks zsh's
  `preexec` directly and does **not** honor `setopt histignorespace` (the
  .zshrc option that makes zsh's own history drop space-prefixed commands).
  The `^\\s` regex replicates that behavior for atuin's own db — without it,
  a command you meant to keep out of history (e.g. one with a bare secret
  typed inline) would still land in atuin even though zsh's `$HISTFILE`
  skipped it. `^cd\\b` / `^j\\b` (added 2026-07-18) drop bare `cd` and the
  `j` auto-jump command (zoxide-style directory jumper) — pure navigation
  noise, never worth re-running from history. The `\b` word boundary keeps
  these from matching lookalikes (`cdw`, `jq`, `journalctl`, …). New matches
  aren't retroactive — after adding a pattern, run `atuin history prune
  --dry-run` to preview and `atuin history prune` to delete already-recorded
  entries that now match (used once already: 63 `cd` + 5 `j dot` entries
  pruned on first setup).
- Everything else is atuin's default: `search_mode = "fuzzy"`,
  `secrets_filter = true` (redacts AWS keys / GitHub PATs / etc. from
  recorded commands), `keymap_mode = "emacs"`, `style = "compact"`. Full key
  reference: <https://docs.atuin.sh/cli/configuration/config/>.

## Usage playbook

1. **Rebuild** to install atuin and stow the config:
   `nrs` (or `sudo nixos-rebuild switch --flake .#nebula` on nebula).
2. **Open a new shell** (or `exec zsh`) — the `eval "$(atuin init zsh)"` hook
   only runs on shell start.
3. **One-time: import existing zsh history** into atuin's db so old commands
   are searchable from day one:
   ```sh
   atuin import zsh
   ```
   Safe to re-run; it dedupes against what's already imported. From this
   point on, every new command is recorded automatically via the shell hook
   — no further import needed.
4. **Search**: press **Ctrl-R** anywhere on the command line. Type to fuzzy-
   filter; the list narrows live.
5. **Navigate the results**: Up/Down (or Ctrl-P/Ctrl-N) to move the
   selection, **Enter** to accept and run immediately (`enter_accept =
   true` is the default), **Tab** to accept into the prompt without running,
   **Esc** to cancel and restore what you'd typed.
6. **Up-arrow** also opens atuin's picker pre-filtered to the current
   directory's history (`filter_mode_shell_up_key_binding`) — press it
   repeatedly to step back through matches like a normal shell, or Ctrl-R to
   drop into the full fuzzy search instead.
7. **Cycle filter scope** inside the picker with **Ctrl-R** again (global →
   host → session → directory) if you need to narrow beyond fuzzy matching.
8. **Stats**: `atuin stats day` / `atuin stats week` for a summary of what
   you've been running.
9. **Prune a command you don't want remembered** (typed a real secret without
   the leading-space trick): `atuin search <term>` to find it, then
   `atuin history delete --exact -- '<the exact command>'`.

## Desktop app (nebula only)

`pkgs.atuin-desktop` (0.2.20, Apache-2.0, Tauri GUI) — "local-first,
executable runbook editor," a separate app from the CLI above, built by the
same project. Installed nebula-only via
[atuin-desktop](../knowledge/modules/atuin-desktop.md)
(`modules/nixos/atuin-desktop.nix`, universal within the nixos class —
retrofit a `programs.atuin-desktop.enable` gate if a second, non-desktop
NixOS host ever appears). Ships its own `.desktop` entry and icons in the
derivation itself, so `environment.systemPackages` is the whole module —
Fuzzel/app launchers pick it up with no `desktop-entries` stow work needed.
Launch: `atuin-desktop`, or "Atuin Desktop" from the app launcher. Keeps its
own state, separate from the CLI: `~/.config/sh.atuin.app/*.db` (runbooks,
kv, ai session, exec log — all SQLite) and `~/.local/share/sh.atuin.app/`
(webview storage/logs); doesn't touch `~/.local/share/atuin/history.db`.

**Known bug, first launch, always reproduces on a Nix install**: the
"Welcome to Atuin Desktop" setup screen fails with *"Failed to create
welcome workspace — Permission denied (os error 13)"*. Root cause (read
straight from `backend/src/commands/workspaces.rs` in the
[atuinsh/desktop](https://github.com/atuinsh/desktop) source, tag v0.2.20):
`copy_welcome_workspace` copies the app's bundled example workspace
(`resources/welcome`, inside the Nix store) into
`~/Documents/Atuin Runbooks/Welcome to Atuin`, then immediately rewrites
that copy's `atuin.toml` to stamp a fresh workspace ID. The copy step uses
Rust's `fs::copy`, which **preserves the source file's permission bits** —
and every file in `/nix/store` is mode `444` (no write bit, by design, on
every Nix install everywhere). So the freshly-copied `atuin.toml` lands in
`~/Documents` still read-only, and the very next write to it fails with
EACCES. Verified live on nebula 2026-07-18: the copied
`Welcome to Atuin/atuin.toml` really is `444`, matching the source file's
mode in the store exactly. This isn't a NixOS/nix-darwin packaging bug (no
`postFixup`/`wrapProgram` could fix it — Nix makes *all* store paths
read-only unconditionally) — it's upstream application logic that doesn't
expect its own bundled resources to be non-writable, which is only true
on Nix. Not yet reported upstream.

**Workaround**: skip the auto-copied welcome workspace; use "Create new
workspace" in the app instead (an ordinary empty directory the app creates
itself, not a copy of a read-only source, so it doesn't hit this path). If
you do want the welcome examples, `chmod -R u+w` the copied folder
immediately after the dialog appears, dismiss it, and retry — the retry
copies over the now-writable target and no longer collides (untested; the
next `copy_welcome_workspace` call still generates a fresh suffixed folder
rather than reusing the fixed one, so this may need a couple of attempts).

**Second known bug, also fixed nebula-side**: the "Atuin Hub Connection"
dialog's **Accept button did nothing — clicking it repeatedly never
dismissed the dialog.** Root cause (read straight from
`src/components/DesktopConnect/DesktopConnect.tsx` and `src/api/auth.ts`
upstream): `confirm()` does `await setHubApiToken(...)` with **no
try/catch** — that call invokes the Tauri `save_password` command, which
writes to the OS's Secret Service (`org.freedesktop.secrets` over D-Bus).
This repo runs no desktop keyring by design (1Password/pass/gpg-agent
instead), so that D-Bus call had no service to talk to, threw, and the
unhandled rejection aborted `confirm()`
before it ever reached the line that closes the dialog. Confirmed via
`busctl --user status org.freedesktop.secrets` → no owner, and no
gnome-keyring/kwallet process running.

**Fix**: added [gnome-keyring](../knowledge/modules/gnome-keyring.md)
(`modules/nixos/gnome-keyring.nix`, `services.gnome.gnome-keyring.enable =
true;`) — `ly`'s own module auto-wires PAM unlock off that option, so login
unlocks the keyring with no extra config. This module had **zero effect at
first**: `modules/hosts/nebula/sudo-1password.nix` already had
`services.gnome.gnome-keyring.enable = lib.mkForce false;` (from the earlier
1Password sudo-ssh-agent setup, to keep `gcr-ssh-agent` from stealing
`SSH_AUTH_SOCK` from the 1Password agent) — `mkForce` always wins over a
plain `= true`. That line went further than its own adjacent comment's
stated intent ("keyring secrets/pkcs11 stay enabled") — the actual conflict
is already fully isolated one line above by
`services.gnome.gcr-ssh-agent.enable = false;` alone, so the `mkForce` was
simply removed rather than out-forced. Verified: `gnome-keyring.enable` →
`true`, `gcr-ssh-agent.enable` stays `false`, full nebula closure builds.
Needs a rebuild + fresh login (or a manual `gnome-keyring-daemon --unlock`)
to take effect — untested end-to-end through an actual Accept click as of
this writing.

The frontend bug (missing try/catch, no user-visible error) is still worth
reporting upstream regardless of the environment fix — on any install
without a Secret Service (this one, minimal Wayland compositors generally,
some containers), the dialog would hang identically with zero feedback.

## Atuin AI & Claude Code integration (set up 2026-07-18)

Three independent features, all under `atuin ai`/`atuin mcp`/`atuin hook` (see
`atuin --help`):

1. **Atuin AI itself** — `?` on an empty zsh/bash/fish prompt opens an inline
   natural-language command assistant (generate a command, ask "why did that
   fail" using last-command context, follow up conversationally). Backed by
   an Atuin Hub account (free during testing) unless self-hosted. Config:
   `[ai]` section in `home/atuin/.config/atuin/config.toml`, currently just
   `enabled = true` (defaults to `false`). Other keys (`model`, `endpoint`,
   `api_token`, `[ai.capabilities]`, `[ai.opening]`) documented inline —
   don't set `yolo = true`, it bypasses all permission checks. **First
   interactive use needs a real terminal**: it triggers a browser-based Hub
   login, same `!`-relay ENXIO panic as `atuin login` (see Learned
   behaviours below) — do the first `?` invocation from a real terminal
   window, not through Claude Code.
2. **MCP server, Claude Code → atuin history (read-only)**: registered at
   user scope (`claude mcp add atuin -s user -- atuin mcp`, so it's live in
   every project, not just this repo) via `~/.claude.json`. Exposes
   `atuin_history` (fuzzy search, filter by directory/session/failed/author)
   and `atuin_output` (fetch captured output of a past command — needs the
   daemon + pty-proxy running, otherwise errors cleanly). Verify:
   `claude mcp list` → `atuin: atuin mcp - ✔ Connected`.
3. **Agent hook, Claude Code → atuin history (the reverse direction)**:
   `atuin hook install claude-code` wrote `PreToolUse`/`PostToolUse`/
   `PostToolUseFailure` entries into `~/.claude/settings.json` (`atuin hook
   claude-code` command). Every Bash command Claude Code runs now lands in
   atuin history tagged `author: claude-code` — filter with `atuin search
   --author claude-code -- ''` (or `--author '$all-agent'` for any agent,
   `--author '$all-user'` to exclude all agents — this is the interactive
   search TUI's default). Takes effect for new Claude Code sessions, not
   retroactively for one already running. Idempotent to re-run.
   `~/.claude/settings.json` isn't part of the dotfiles stow tree (it's a
   Claude Code–owned file, not this repo's), so this hook install doesn't
   survive a fresh-machine setup automatically — rerun `atuin hook install
   claude-code` on `k`/`mini` too.

## Sync (enabled and working, verified 2026-07-18)

`auto_sync = true` in `config.toml`. Atuin 18.x defaults to **Hub-native
sync** (`settings.is_hub_sync()` true by default) — the old key-based
"legacy" `api.atuin.sh` login is a separate, no-longer-default code path
(`crates/atuin/src/command/client/account/login.rs`,
`run_hub_login`/`run_legacy_login`). This matters because it changes where
the session lives and which commands are relevant:

- **Setup on nebula**: `atuin login -u k-atuin` in a real terminal (see
  Learned behaviours — this panics under Claude Code's `!` relay, needs a
  real tty for the password/key prompts). With `-u` given, it takes the
  headless Hub path: prompts for encryption key then password, authenticates,
  and — because the returned token has the `atapi_` prefix — saves it as
  `hub_session` via `meta.save_hub_session()`. **No
  `~/.local/share/atuin/session` file gets created** — that's the old
  legacy-login artifact and doesn't exist on the Hub path. Check real state
  with `sqlite3 ~/.local/share/atuin/meta.db "SELECT * FROM meta"` (look for
  a `hub_session` row), not by looking for a session file.
- **`atuin account link` does not apply here and its error is expected.**
  Read straight from upstream `link.rs`: it requires a *legacy*
  `session_token` to exist locally before it'll do anything — that's only
  ever set by `run_legacy_login`, which the Hub-native path never calls. A
  Hub-native `atuin login` already does its own silent
  `atuin_client::hub::link_account()` call internally. Running
  `atuin account link` afterward just errors "No CLI session found" — not a
  sign anything is broken, just the wrong command for this account type.
- **Verify sync actually works with `atuin sync`, not `atuin status`.**
  `atuin status`'s `Last sync` field did not visibly update immediately
  after either the login or a manual `atuin sync` in testing — don't trust
  it as a live indicator. `atuin sync`'s own output is the real signal;
  confirmed live: `Uploading N records to <host_id>/history` /
  `Sync complete! N items in history database`.

To bring `k`/`mini` into the same sync group: `atuin login -u k-atuin` there
too (same account, real terminal, not `register`) — no `account link` step
needed on Nix hosts.

**Security note**: the desktop app's Hub registration passes a token via a
custom URI scheme (`atuin://register-token/atapi_...`) printed straight to
stdout by `atuin-desktop` when launched from a terminal — happened live on
2026-07-18 and landed in a chat transcript. If that ever happens again,
treat the token as compromised and rotate/revoke it from Hub account
settings; don't launch `atuin-desktop` from a terminal you're screen-sharing
or pasting output from during the Hub-connect flow.

## Learned behaviours & workarounds

- **`atuin login`/`register` panic under Claude Code's `!` command relay.**
  The password/encryption-key prompts (`rpassword`) open `/dev/tty` directly
  for secure input — same pattern as `sudo`/`ssh-add`. Through the `!` relay
  this fails: `panicked ... Failed to read from input: Os { code: 6, kind:
  Uncategorized, message: "No such device or address" }` (ENXIO — no
  controlling terminal). Any atuin command with an interactive secret prompt
  needs a real terminal window, not the relay. (2026-07-18)
- **atuin does not read zsh's `HISTORY_IGNORE`/`histignorespace`.** It hooks
  `preexec` directly and keeps its own db, so zsh-level history exclusion
  doesn't apply to it — needs its own `history_filter` regex (see Config
  above). Confirmed via upstream issue tracker, not by reading atuin's
  source directly. (2026-07-18)
- **Bind order matters**: `atuin init zsh` must be eval'd after `fzf --zsh`
  in `integrations.zsh`, same constraint hstr had — whichever runs last wins
  Ctrl-R. (2026-07-18)
- **First-ever `nrs` after adding this module left `~/.config/atuin/config.toml`
  as a real (unconfigured) file, not the repo symlink.** Something invoked
  `atuin`/`atuin-desktop` before that `nrs` ran (before the CLI was even on
  `PATH` — most likely atuin-desktop's own first-run "is the CLI installed?"
  check), which made the CLI auto-write its full commented default template
  to that path. Stow then found a real file already sitting where it wanted
  to place a symlink and silently skipped the whole `atuin` package (one
  file = one package here, so the skip was total) — `history_filter` /
  `auto_sync` / `update_check` were never actually applied. Fixed by hand:
  `rm ~/.config/atuin/config.toml && stow -d ~/src/dotfiles/home -t ~
  --no-folding --restow atuin`. General lesson for this repo: a brand-new
  stow package's target path should be verified empty (or the stray file
  removed) after the first rebuild that introduces it — stow conflicts fail
  silently from the caller's point of view unless you're watching the
  activation script's own stdout. (2026-07-18)

## Sources

- [atuin config.toml reference](https://docs.atuin.sh/cli/configuration/config/)
- [atuin key-binding reference](https://docs.atuin.sh/cli/configuration/key-binding/)
- [GitHub issue #114 — history_filter vs HISTORY_IGNORE](https://github.com/atuinsh/atuin/issues/114)
- [atuinsh/desktop `backend/src/commands/workspaces.rs`](https://github.com/atuinsh/desktop/blob/main/backend/src/commands/workspaces.rs) (v0.2.20 tag) — `copy_welcome_workspace`, read directly to find the EACCES root cause
- Live verification on nebula, 2026-07-18: `stat` on the copied `atuin.toml` and its Nix store source, both `444`
