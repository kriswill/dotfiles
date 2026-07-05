---
type: Reference
title: Task Manuals (docs/)
description: Entry point to the docs/ manuals layer — task-focused, machine-verified operational references with dated learnings, complementing knowledge/'s durable rationale and catalog.
resource: docs
tags: [docs, manuals, reference]
timestamp: '2026-07-03T12:00:00-07:00'
---

The repo keeps two documentation layers with a deliberate division of labor
(per [AGENTS.md](../AGENTS.md)): **knowledge/** (this bundle) holds durable
rationale — patterns, decision records, playbooks — and the scaffolded
component catalog; **docs/** holds task-focused operational manuals, each
researched and machine-verified, leading with the verified version/state and
carrying a dated "Learned behaviours & workarounds" section. Consult the
relevant manual before working on its topic, and correct stale claims in place
rather than appending contradictions. Larger topics use a `docs/<tool>/`
subdirectory: a `manual.md` hub, topic docs, and an append-only
`learnings.md` (first instance: `docs/svelt/`). This listing is
hand-maintained — adding a manual under `docs/` means adding a bullet here;
versions live in the manuals themselves, which lead with verified state.

## Linux desktop (nebula)

- [`docs/hyprland.md`](../docs/hyprland.md) — Lua-first configuration manual
  for Hyprland: the `hl.*` API, binds/rules/monitors, legacy
  `.conf`→Lua translation map, and a large dated gotcha log (`.conf` shadows
  `.lua`, OLED 240Hz DSC failure, NVIDIA/XWayland scaling).
- [`docs/noctalia.md`](../docs/noctalia.md) — Noctalia: install wiring,
  two-layer TOML config + `noctalia-config` snapshot sync, IPC/CLI surface,
  theming templates, and DDC/CI brightness enablement.
- [`docs/helium.md`](../docs/helium.md) — Helium browser: the
  load-bearing fact that unbranded-Chromium Helium reads stock
  `/etc/chromium/policies` paths, the declarative managed-policy module, and
  the age-encrypted `helium-config` snapshot workflow.
- [`docs/hdr-hyprland-june-2026.md`](../docs/hdr-hyprland-june-2026.md) —
  verified HDR state on nebula's OLED under Hyprland/NVIDIA:
  `cm = "auto"` desktop config, reading `hyprctl monitors`, and the full
  (failed) campaign to get WoW into HDR via Proton-Wayland and nested
  gamescope.
- [`docs/libreoffice.md`](../docs/libreoffice.md) — how two NixOS modules fix
  LibreOffice (`gtk-dark.nix` dark theming; `libreoffice-paths.nix` seeding
  modern + legacy path nodes into `registrymodifications.xcu` for XDG data
  dirs), with source-level root-cause analysis.
- [`docs/fastfetch.md`](../docs/fastfetch.md) — fastfetch under
  ghostty+Hyprland+tmux: why only `logo.type: "kitty-icat"` renders the PNG,
  the `TERM == "screen"` image guard, and a grim/ghostty screenshot test
  harness.
- [`docs/suspend.md`](../docs/suspend.md) — S3/`deep` suspend reference whose
  single load-bearing fact is the MSI BIOS setting `Wake Up Event By = OS`
  (non-declarative, lost on CMOS reset), plus wake-diagnosis commands.

## Cross-platform tools

- [`docs/tmux.md`](../docs/tmux.md) — tmux reference covering the
  stow/Nix split (static `tmux.conf` stowed, `plugins.conf` generated per OS)
  and the load-bearing `default-terminal "tmux-256color"` +
  `allow-passthrough all` pair that makes in-pane images work.
- [`docs/neovim-testing.md`](../docs/neovim-testing.md) — recipe for
  verifying Neovim UI changes in a real Neovide GUI session via the
  computer-use MCP, with an osascript/screencapture fallback (caveat: still
  describes retired home-manager machinery — needs correction).
- [`docs/svelt/manual.md`](../docs/svelt/manual.md) —
  [Svelte](svelte-language.md) + SvelteKit
  hub: runes and template cheat sheets, tooling table,
  this repo's nvim Svelte wiring; topic docs
  [`runes.md`](../docs/svelt/runes.md),
  [`sveltekit.md`](../docs/svelt/sveltekit.md),
  [`migration-svelte4-to-5.md`](../docs/svelt/migration-svelte4-to-5.md) and
  the dated gotcha log [`learnings.md`](../docs/svelt/learnings.md).

## Research & incident reports

- [`docs/bootloader-issues-jun-06.md`](../docs/bootloader-issues-jun-06.md) —
  diagnosis of nebula's June-2026 unbootable-generations incident (an
  activation-script `exit 0` aborting boot-time activation + intermittent
  GRUB initrd reads), ending with the deliberate return to GRUB+os-prober for
  Windows dual-boot.
- [`docs/security-audit-cve-jun-2026.md`](../docs/security-audit-cve-jun-2026.md)
  — June-2026 CVE audit of GnuPG and Linux-PAM on nebula,
  concluding nothing is exploitable and no remediation is needed.
- [`docs/hdr-niri-june-2026.md`](../docs/hdr-niri-june-2026.md) — historical
  (niri-session-only) finding that niri has no
  `wp_color_management_v1` and hence no HDR; superseded by the Hyprland HDR
  doc, and niri has since been removed.

## Citations

- [AGENTS.md — "Manuals (docs/)"](../AGENTS.md)
