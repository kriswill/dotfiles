---
type: Decision
title: Patch Herdr to Render Metadata Tokens as Color Bars
description: The pinned herdr input carries a source patch adding a `{ type = "token", bar = true }` ui.tab_bar_right entry that renders a focused-workspace metadata token as a full-color braille bar — because the tab bar sanitizes away ANSI and hard-codes segment styles, leaving no smuggling route.
tags: [herdr, patch, claude]
timestamp: '2026-08-30T14:30:00-07:00'
---

**Status:** active. **Where:**
[`overlays/herdr-tab-bar-token.patch`](../../overlays/herdr-tab-bar-token.patch),
wired in [`modules/overlays.nix`](../../modules/overlays.nix);
both [herdr](../modules/herdr.md) class modules consume the overlaid
`pkgs.herdr`.

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

The watcher dual-publishes during the transition: the legacy `command`
state-file entry keeps working under the running unpatched server, while
`usage`/`usage_fable` workspace tokens (15 s TTL) feed the commented token
config in `home/herdr/.config/herdr/config.toml`, to be swapped in after a
rebuild + herdr server restart.

## Consequences

- Full-color, poll-free bars once live; the token entry is workspace-scoped
  but the watcher still clears tokens on tab unfocus, preserving tab-level
  semantics.
- The patch must be rebased on every herdr input bump (it touches UI
  internals with no stability guarantee) — a good candidate to upstream,
  which would also honor upstream's external-contributor policy noted in
  their build banner.
- Until the server restart, the token entries stay commented: the running
  v0.8.2 binary's `deny_unknown_fields` config parse would reject
  `type = "token"`.

## Citations

- Commit `959a9c8`
- [herdr repository](https://github.com/herdrdev/herdr) (patched rev
  `9eb5214`, tag v0.8.2)
