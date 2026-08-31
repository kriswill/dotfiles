---
type: Decision
title: Replace the Token-Bar Patch with ANSI Tab-Bar Command Entries
description: The fork's bespoke `{ type = "token", bar = true }` renderer is replaced by generalized command entries (`argv` + `ansi` fields) — herdr injects workspace metadata tokens as HERDR_TOKEN_* env and re-runs the command reactively, so bar rendering moves out of the patched binary into the userland dotbar-usage script.
tags: [herdr, claude, statusline]
timestamp: '2026-08-30T17:45:00-07:00'
---

**Status:** active — since 2026-08-30 (commit `40a9543`; fork rev `b1b9e98`,
stamped into the binary as `0.8.2-kriswill-custom.b1b9e98` by the
build-identity overlay, commit `c4b2ced`). Supersedes the render half of the
[token-bar patch](herdr-token-bar-patch.md). **Where:**
[`home/herdr/.config/herdr/config.toml`](../../home/herdr/.config/herdr/config.toml),
[`home/herdr/.local/bin/dotbar-usage`](../../home/herdr/.local/bin/dotbar-usage),
[`modules/overlays.nix`](../../modules/overlays.nix),
[`flake.nix`](../../flake.nix) herdr input
([herdr](../modules/herdr.md), [dotbar](../packages/dotbar.md)).

## Context

The [token-bar patch](herdr-token-bar-patch.md) worked, but it hard-coded
the entire rendering (3-cell braille bar, fill ramp, gradient, `NN%` label)
in the patched Rust core: every styling tweak meant editing fork commits and
rebuilding herdr, and a bespoke `{ type = "token" }` entry that duplicates
dotbar's rendering is a weak upstreaming candidate. The underlying blockers
were narrower than a custom renderer: the tab bar sanitized ANSI out of
command output, and command entries couldn't see workspace metadata tokens
or react to their changes.

## Decision

Rework the fork (`custom` branch, rev `b1b9e98`) to generalize
`ui.tab_bar_right` command entries instead of adding a token entry type:

- **`argv` field** — run the command directly, no shell;
- **`ansi = true`** — render the command's SGR-colored output inline
  instead of sanitizing it;
- **token env + reactivity** — herdr injects the focused workspace's
  metadata tokens as `HERDR_TOKEN_*` env vars and re-runs the command
  whenever they change, so `interval_seconds` (300) is only a safety
  refresh, not the update path.

Rendering moves to userland:
[`dotbar-usage`](../../home/herdr/.local/bin/dotbar-usage) (in the `herdr`
stow package, deployed on both OSes) renders `HERDR_TOKEN_USAGE` /
`HERDR_TOKEN_USAGE_FABLE` as dim `wk`/`F5` labels plus
[dotbar](../packages/dotbar.md) `--dense` braille bars; empty output hides
the entry. The config collapses to one `command` entry; the
[watcher](herdr-usage-tab-indicator.md)'s token publishing is unchanged.

The overlay no longer patches anything — it only stamps build identity
(`HERDR_BUILD_CHANNEL=kriswill-custom`, `HERDR_BUILD_ID=<shortRev>` via
upstream's `build_info.rs` compile-time hooks) so `herdr --version` shows
the fork rev at a glance.

## Consequences

- Bar styling is now a script edit (stow symlink — live on next tab-bar
  refresh), not a fork rebase + rebuild; the fork carries a generic
  capability (ANSI command entries) rather than a dotbar clone, a much
  stronger upstreaming candidate.
- The `custom` branch must still be rebased onto each upstream tag
  ([herdr-update-check](../modules/herdr-update-check.md) is the reminder),
  and config using `argv`/`ansi` fields still requires the fork binary
  everywhere the shared stow config is parsed — an unpatched herdr's
  `deny_unknown_fields` rejects it.
- The plugin-v1 research in the [token-bar patch
  record](herdr-token-bar-patch.md) still applies: plugins get no tab-bar
  UI, so even the generalized entry stays core.

## Citations

- Commits `40a9543` (config + script + input bump), `c4b2ced` (build identity)
- [kriswill/herdr staging fork](https://github.com/kriswill/herdr) (`custom`
  branch, rev `b1b9e98`)
- [herdr repository](https://github.com/herdrdev/herdr)
