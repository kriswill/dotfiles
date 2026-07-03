---
type: Pattern
title: Snapshot-Synced Configs
description: Apps that rewrite their config via atomic rename (Helium, Noctalia) can't be stowed — settings are git-tracked as snapshots under config/, synced explicitly with per-app capture/restore/diff CLIs; Helium's snapshots are age-encrypted at rest.
resource: config/README.md
tags: [config, snapshots, age, stow]
timestamp: '2026-07-03T12:00:00-07:00'
---

The repo's third config mechanism, beside the [stow tree](stow-tree.md) and
[module-generated files](store-path-configs.md). Some apps save settings by
writing a same-dir temp file and `rename()`-ing it over the target
(Helium/Chromium, Noctalia): the atomic rename **destroys a per-file stow
symlink on the first save**, silently breaking tracking — and since `home/` is
auto-restowed every rebuild, a stowed copy would then symlink the repo copy
*over* the live profile and clobber it. The directory-symlink workaround was
rejected after an adversarial bake-off (2 critical + ~6 high data-loss
vectors: routine git ops like `reset --hard` mutate the *running* config, and
runtime state — clipboard secrets, nested plugin `.git` dirs — lands in the
repo; see the header of
[`pkgs/noctalia-config.nix`](../../pkgs/noctalia-config.nix)). Resolution:
the live file and the repo snapshot stay **physically separate**, synced
explicitly.

The shape:

- **`config/<app>/` holds plain git-tracked snapshots** — deliberately outside
  `home/` (never stowed) and outside `modules/` (never evaluated by
  import-tree). Full design: [`config/README.md`](../../config/README.md).
- **A per-app CLI** built from `pkgs/<app>-config.nix`
  (`writeShellApplication`) exposes the same three verbs everywhere:
  `capture` (allowlist copy live → repo; prints the `git diff` command, never
  auto-commits), `restore` (backs up the live file to `.bak`, writes via temp
  + atomic rename — the app's own save pattern — re-hardens permissions to
  `0600`, and refuses while the app runs via `pgrep` unless `FORCE=1`), and
  `diff`.
- **Churn filtering**: [helium-config](../packages/helium-config.md)'s JSON
  snapshots are `jq`-filtered (window geometry, `exit_type: Crashed`,
  timestamps, metrics) and key-sorted for stable diffs; the filter lists live
  at the top of `pkgs/helium-config.sh`.
- **Age encryption at rest (Helium only)**: every snapshot is
  armored-encrypted to `config/helium/<rel>.age`. The recipient is the
  *public* key `keyring.age.nebula`, so `capture` runs unattended;
  `restore`/`diff` pull the identity from 1Password via `op read` into memory
  only. This is deliberately a separate mechanism from sops-nix (see the
  [sops decision](../decisions/sops-darwin-ssh-host-keys.md)).
  [noctalia-config](../packages/noctalia-config.md) stays plaintext — its
  `settings.toml` carries no PII. Caveat: `Cookies`/`Login Data` are
  `os_crypt`-bound SQLite — they restore only on the machine that captured
  them.
- **Deployment wiring**: register in [packages](../modules/packages.md) plus
  an `overlays/<app>-config.nix`, then put the CLI on `k`'s PATH via
  `modules/hosts/nebula/users/k/<app>.nix`
  ([users-k-helium](../modules/users-k-helium.md),
  [users-k-noctalia](../modules/users-k-noctalia.md)). Linux/nebula-only
  today; the prerequisites for extending Helium to macOS (profile path,
  per-host snapshot subtrees, multi-recipient age) are enumerated in the
  [unification decision](../decisions/nixos-darwin-unification.md) —
  deliberately unbuilt until Helium actually runs on a Mac.

Adding an app is the four-step recipe in
[`config/README.md`](../../config/README.md): write `pkgs/<app>-config.nix`
(model on helium-config or noctalia-config), register package + overlay, add
the nebula user file, `capture` and `git add` the snapshot.

Tradeoffs: manual sync discipline (capture after settings edits; restore
wants the app quit) and allowlist maintenance when the app grows files, in
exchange for zero corruption/leak risk; encrypted snapshots are undiffable in
the GitHub UI, and single-recipient encryption blocks multi-host use until it
is actually needed.

## Citations

- [`config/README.md`](../../config/README.md)
- [`pkgs/helium-config.nix`](../../pkgs/helium-config.nix) + [`pkgs/helium-config.sh`](../../pkgs/helium-config.sh), [`pkgs/noctalia-config.nix`](../../pkgs/noctalia-config.nix)
- Reached main with the dual-OS merge `76a05ff` (PR #22, `0b8a629`)
