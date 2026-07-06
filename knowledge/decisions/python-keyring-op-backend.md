---
type: Decision
title: Back python-keyring with 1Password, Not a Keyring Daemon
description: 'Gajim needed a password store; instead of running gnome-keyring, a ~60-line vendored python-keyring backend shells out to `op`, keeping every secret in 1Password. Serializes `op` calls with a file lock so Gajim''s parallel connect fetches don''t collide and reset the desktop-app integration.'
tags: [secrets, 1password, keyring, stow]
timestamp: '2026-07-05T20:30:00-07:00'
---

**Status:** active. **Where:** `home/python-keyring/` (backend), plus
`home/local-bin/gajim-op-launch` + a `home/desktop-entries/org.gajim.Gajim.desktop`
override for the launch-race fix — all Linux-only stow packages, skip-listed in
[dotfiles-stow](../modules/dotfiles-stow.md)'s darwin twin.

## Context

Gajim saves account passwords through the Python `keyring` library, whose
default backend (secretstorage) needs an `org.freedesktop.secrets` daemon on
D-Bus. nebula runs none, so Gajim prompted every launch and offered no "Save
Password". The standard fix — enabling gnome-keyring — would add a second
secret store, against this machine's standing preference for 1Password as the
single trust root ([sudo](../modules/sudo-1password.md), git signing, sops age
key via `op read`). 1Password itself does not implement the Secret Service
API, and no maintained bridge exists (checked 2026-07: rosec supports
Bitwarden/KeePassXC only; `onepassword-keyring` on PyPI is an unmaintained
personal fork).

## Decision

Vendor a minimal `keyring` backend in the stow tree instead of adding any
daemon or package:

- `home/python-keyring/.config/python_keyring/backends/op_keyring.py` — a
  `KeyringBackend` whose get/set/delete shell out to `op item get/create/delete`.
  Items are Password-category entries titled
  `python-keyring/<service>/<username>`, tagged `python-keyring`, in the
  default vault. Passwords travel via stdin JSON (never argv, which is
  world-readable in /proc).
- `keyringrc.cfg` selects it via `default-keyring=` + `keyring-path=`, so the
  backend needs no entry-point install — any python-keyring consumer picks it
  up from config alone; Gajim's bundled keyring 25.7 honors it unmodified.

## Consequences

- Gajim's "Save Password" works; the secret lives only in 1Password, read at
  connect time (in-memory, nothing at rest on the unencrypted disk).
- **Root cause of the "keystore not working" reports: a stale/missing `op` CLI
  session, so each fetch does a fresh integration handshake that intermittently
  resets (diagnosed 2026-07-05).** `op` reaches the 1Password app over
  `/run/user/1000/1Password-BrowserSupport.sock` (found via `strace -e connect`).
  A bare `op item get` with no cached session does a full desktop-app handshake,
  which intermittently fails with `error initializing client: connecting to
  desktop app: connection reset`. Gajim reads its password from the keyring
  exactly **once per connect with no retry**, so one failed handshake → empty
  password → "Password Required" dialog + offline. The user found the tell:
  running `op signin` (then `op whoami`) by hand makes it work — `op signin`
  performs the handshake once and **caches a session in `~/.config/op/config`
  that later, separate processes reuse** (verified: a fresh process sees the
  primed session), so Gajim's subsequent `op item get` skips the flaky
  handshake. (`op whoami` alone is not a valid readiness probe — it checks for a
  CLI signin token the app-integration path never mints and always reports "not
  signed in"; `op item get`/`op account get` go through the integration.)
  **Fix (two layers):**
  1. `~/.local/bin/gajim-op-launch` (stow pkg `home/local-bin`, Linux-only)
     runs `timeout 30 op signin` to prime the session, then `exec gajim`. The
     handshake happens before Gajim's process exists → no UI-thread blocking;
     non-interactive when the app is unlocked, pops the mini-login when locked.
     `home/desktop-entries/.local/share/applications/org.gajim.Gajim.desktop`
     overrides the packaged entry to call it. **Two launcher gotchas, both
     load-bearing:** (a) the `Exec` must use the **absolute path** — the
     systemd-`--user`/Noctalia launcher `PATH` lacks `~/.local/bin`, so a bare
     name silently fails to launch (empty log, nothing happens); (b) Noctalia
     (long-running Quickshell) **caches desktop entries** and does not re-read a
     stow *symlink* whose target changed — recreate the symlink (`rm` + restow)
     to fire a dir-level CREATE, or reload Noctalia. fuzzel rescans every open,
     so it always sees the current entry (useful to isolate launcher-cache
     issues). Verified: launched from both fuzzel and Noctalia, `op signin` /
     `op item get` return rc=0 and Gajim connects.
  2. Backend serializes every `op` call with a cross-process `fcntl.flock` on
     `~/.local/state/op_keyring.lock` (concurrent `op` also triggers the reset)
     and logs each non-zero exit to `~/.local/state/op_keyring.log` (a first-try
     success logs nothing).
  **Known gap:** the wrapper only primes at *launch*. Gajim re-fetches on every
  reconnect (network change / server drop) on its UI thread, unprotected — if
  the cached session has lapsed a reconnect can still drop to the dialog. Not
  fixable from the keyring side without patching Gajim to retry.
  **Rejected:** a blocking retry loop in `get_password` — Gajim calls the
  keyring synchronously on its GLib main loop, so retry sleeps (6×3 s) froze the
  UI into "Application Not Responding". Prime before launch instead.
- Lock-state note: `op` reads are gated by the app's lock state, not a per-use
  prompt. It uses the CLI integration (`developers.cliSharedLockState.enabled`
  in `~/.config/1Password/settings/settings.json`) — locked → mini-login pops
  on fetch; unlocked → reads are silent for any process running as the user.
  This differs from the SSH-agent path ([sudo](../modules/sudo-1password.md),
  git signing), which prompts per requesting application even while unlocked;
  1Password offers no per-app approval layer for the CLI on Linux. (This is a
  property, not the failure — the collisions above happen while unlocked.)
- The config hardcodes `/home/k` (keyring-path can't expand `~`); a second
  Linux user would need their own copy.

## Citations

- [`home/python-keyring/`](../../home/python-keyring/.config/python_keyring/backends/op_keyring.py)
- [python-keyring config docs](https://github.com/jaraco/keyring#configuring) — `keyringrc.cfg`, `keyring-path`
- [op item create](https://www.1password.dev/cli/reference/management-commands/item/#item-create) — stdin JSON template
