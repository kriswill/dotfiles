---
type: Decision
title: Back python-keyring with 1Password, Not a Keyring Daemon
description: 'Gajim needed a password store; instead of running gnome-keyring, a ~60-line vendored python-keyring backend shells out to `op`, keeping every secret in 1Password behind its authorization prompt.'
tags: [secrets, 1password, keyring, stow]
timestamp: '2026-07-05T20:30:00-07:00'
---

**Status:** active. **Where:** `home/python-keyring/` (stow package, Linux-only —
skip-listed in [dotfiles-stow](../modules/dotfiles-stow.md)'s darwin twin).

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
  connect time behind the app's authorization prompt (in-memory, nothing at
  rest on the unencrypted disk).
- Every python-keyring consumer on nebula now routes to 1Password; if
  1Password is locked and the prompt is dismissed, `get_password` returns
  `None` and the app falls back to asking interactively (reads time out after
  120 s).
- The config hardcodes `/home/k` (keyring-path can't expand `~`); a second
  Linux user would need their own copy.

## Citations

- [`home/python-keyring/`](../../home/python-keyring/.config/python_keyring/backends/op_keyring.py)
- [python-keyring config docs](https://github.com/jaraco/keyring#configuring) — `keyringrc.cfg`, `keyring-path`
- [op item create](https://www.1password.dev/cli/reference/management-commands/item/#item-create) — stdin JSON template
