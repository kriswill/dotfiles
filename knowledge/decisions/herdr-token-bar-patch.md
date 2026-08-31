---
type: Decision
title: Patch Herdr to Render Metadata Tokens as Color Bars
description: The pinned herdr input carries a source patch adding a `{ type = "token", bar = true }` ui.tab_bar_right entry that renders a focused-workspace metadata token as a full-color braille bar — because the tab bar sanitizes away ANSI and hard-codes segment styles, leaving no smuggling route.
tags: [herdr, patch, claude]
timestamp: '2026-08-30T14:30:00-07:00'
---

**Status:** superseded — the bespoke `{ type = "token", bar = true }`
renderer was replaced the same day (2026-08-30) by the fork's generalized
[ANSI tab-bar command entries](herdr-ansi-tab-bar-entries.md), which move
rendering into the userland `dotbar-usage` script. Interim history: the
change first shipped as an in-repo `.patch` + `overrideAttrs` overlay, then
as commit `ec833adc` on the `custom` branch of the [kriswill/herdr staging
fork](https://github.com/kriswill/herdr) (upstream tag + patch commits,
rebased on each upstream release; the codebase-memory-mcp model), consumed
directly as the `herdr` flake input — the fork-consumption model survives;
the token entry type does not.
**Where:** [`flake.nix`](../../flake.nix) herdr input,
[`modules/overlays.nix`](../../modules/overlays.nix);
both [herdr](../modules/herdr.md) class modules consume `pkgs.herdr`.

## Context

The [usage tab-bar indicator](herdr-usage-tab-indicator.md) wanted color, but
herdr's tab bar can't be smuggled ANSI: every command entry's output passes
`sanitize_status_text` (strips all control chars incl. ESC, plus Unicode
format controls), and segments render with one of two hard-coded theme
styles. The sidebar's styled `$name` metadata tokens showed the natural
extension point — workspace metadata already flows to the renderer.

## Decision

Carry a source patch on the pinned herdr flake input (v0.8.2) adding a
`ui.tab_bar_right` entry type:

```toml
{ type = "token", token = "usage", bar = true }
```

It resolves the named token from the **focused workspace's**
`metadata_tokens` at draw time — fully reactive, no polling task. With
`bar = true` the value parses as a percentage and renders as a 3-cell
braille bar (8-step vertical fill ramp, green→yellow→red gradient by cell
position matching dotbar's dense palette, dim `NN%` label); otherwise the
sanitized text renders. Absent tokens hide the entry. Implementation spans
`config/tab_bar.rs` (variant + diagnostics), `app/state.rs` +
`app/tab_bar_status.rs` (segment), and `ui/tabs.rs` (owned segment enum,
multi-span `Line` rendering); includes a buffer-level render test, and the
existing 29 tab-bar tests plus clippy stay green.

Nix side: an inline overlay (`modules/overlays.nix`, closes over `inputs`
like ccglass) exposes `pkgs.herdr` as the input's package
`overrideAttrs`-ed with the patch — Cargo.lock is untouched so the
vendored-deps hash survives. Both class modules switched from
`inputs.herdr.packages…` to `pkgs.herdr`.

The watcher publishes `usage`/`usage_fable` workspace tokens (15 s TTL,
refreshed by its 5 s housekeeping tick, cleared on tab unfocus); the token
entries went live in `home/herdr/.config/herdr/config.toml` after the
rebuild + server restart, and the transitional state-file `command` entry
was removed.

## Consequences

- Full-color, poll-free bars once live; the token entry is workspace-scoped
  but the watcher still clears tokens on tab unfocus, preserving tab-level
  semantics.
- The `custom` branch must be rebased onto every new upstream tag (the
  change touches UI internals with no stability guarantee);
  [herdr-update-check](../modules/herdr-update-check.md) is the reminder.
  Still a good candidate to upstream from a clean feature branch — read
  upstream's CONTRIBUTING.md / APPROVED_CONTRIBUTORS policy first; a merged
  PR drops the commit from `custom` at the next tag.
- **Plugins cannot replace this patch** (researched 2026-08-30 against the
  v0.8.2 source): plugin v1 explicitly excludes "native non-terminal plugin
  UI" — a plugin's only UI surface is terminal panes/popups, so nothing in
  the manifest (`[[actions]]`, `[[events]]`, `[[startup]]`, `[[panes]]`,
  `[[link_handlers]]`) can draw in the tab bar. The *watcher* half could
  become a plugin (manifest `[[events]]` hooks may subscribe to
  `tab.focused` / `pane.exited` — only high-volume kinds are excluded —
  with `HERDR_PLUGIN_EVENT_JSON` context and per-plugin config/state dirs),
  but the renderer stays core. End state remains: upstream the token entry,
  optionally ship the watcher as a marketplace plugin.
- Config with `type = "token"` entries requires the patched binary
  everywhere it's parsed — an unpatched herdr's `deny_unknown_fields`
  rejects it (relevant if nebula rebuilds lag the config, since the stow
  tree is shared).
- **Superseded** (2026-08-30, commit `40a9543`): the token entry type was
  dropped from `custom` in favor of [ANSI command
  entries](herdr-ansi-tab-bar-entries.md) — `argv`/`ansi` fields plus
  `HERDR_TOKEN_*` env injection with reactive re-runs — so the hard-coded
  bar rendering left the binary for `~/.local/bin/dotbar-usage`. The plugin
  research above still holds for the replacement.

## Citations

- Commit `959a9c8`
- [herdr repository](https://github.com/herdrdev/herdr) (patched rev
  `9eb5214`, tag v0.8.2)
