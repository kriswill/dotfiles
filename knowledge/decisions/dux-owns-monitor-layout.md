---
type: Decision
title: Let Dux Own the Monitor Layout, Behind Baseline Rules and OLED Guards
description: 'Dux Shell''s Settings → Displays now controls nebula''s monitor layout. monitors.lua sets baseline rules, then loads Dux''s dms/outputs.lua through a wrapped hl.monitor that accepts only desc: rules and blocks the two settings known to blank the OLED: cm "auto" and refresh rates needing DSC.'
tags: [nixos, hyprland, desktop-shell, dux-shell]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-11-04T16:30:00-08:00 }
sources:
  - id: hyprland-rule-manager
    resource: https://github.com/hyprwm/Hyprland/blob/v0.57.0/src/config/shared/monitor/MonitorRuleManager.cpp
    title: Hyprland v0.57.0 `MonitorRuleManager.cpp` (rule replace-by-name, last-match lookup)
  - id: dux-hyprland-service
    resource: https://github.com/duxlabs-dev/dux-shell/blob/v2.1.0/quickshell/Services/HyprlandService.qml
    title: Dux Shell v2.1.0 `HyprlandService.qml` (buildOutputsLua, writeOutputsConfig)
  - id: dux-shell-manual
    resource: ../../docs/dux-shell.md
    title: docs/dux-shell.md — nebula's Dux Shell manual
  - id: hdr-notes
    resource: ../../docs/hdr-hyprland-june-2026.md
    title: docs/hdr-hyprland-june-2026.md — HDR and cm notes for the PG34WCDM
---

**Where:** [hyprland](../modules/hyprland.md) (`home/hyprland/.config/hypr/monitors.lua`),
[users-k-dux-shell](../modules/users-k-dux-shell.md).

## Context

Moving a display in Dux's Settings → Displays never stuck. Apply writes
`~/.config/hypr/dms/outputs.lua` and runs `hyprctl reload`.[^dux-hyprland-service]
The reload re-ran `monitors.lua`, which hard-coded every position, and Dux's
file was never loaded. That was deliberate at the time
([dux-shell-replaces-noctalia](dux-shell-replaces-noctalia.md)): Dux's
default rules match outputs by connector name, and loading them raw is
unsafe. In Hyprland 0.57 a rule with the same name replaces the earlier one
whole, and lookup takes the last match (`CMonitorRuleManager::add` /
`getMonitorRuleFor`).[^hyprland-rule-manager] So a raw Dux rule silently drops the OLED's
`cm = "srgb"` and its no-DSC refresh rate. Each of those exists because the
alternative blanks the panel: `cm "auto"` drops the DP link when fullscreen
video flips it into PQ, and anything over ~144 Hz at 10-bit needs DSC, which
doesn't negotiate.[^hdr-notes]

## Decision

- **Dux owns the monitor setup.** `monitors.lua` emits complete baseline
  rules, then `require`s `dms.outputs` (searchpath-guarded, under `pcall`)
  with `hl.monitor` wrapped:
  - only `desc:` rules are passed (Dux's Displays → "Name format: Model").
    Connector-named rules and the empty-name catch-all are dropped. Connector
    numbers change across boots here.
  - Dux's rule is taken as written, not merged over the baseline, so a field
    Dux omits (e.g. `transform` after un-rotating) doesn't come back.
  - the OLED's guard rewrites only dangerous values: missing/`auto` `cm` →
    `srgb` (Dux omits `cm` when it is "Auto"); a rate over 144 Hz,
    `preferred` or a bare `WxH` → `3440x1440@143.97`; a non-sRGB `cm`
    without a bit depth gets `bitdepth = 10`.
- **Guards, not pins.** An earlier draft pinned mode, bit depth and `cm` on
  the OLED. That overrode deliberate choices made in Dux, such as trying
  `hdredid`, and recreated the original complaint. Only the two
  blank-screen classes are blocked. HDR modes are cosmetic risks (washed
  out), so they're the user's call.
- **Baseline as fallback.** With no Dux file, a broken one, or "Name"
  format, the baseline layout applies (DP-3 at 1440x1581). Hyprland's
  config-error banner reports a broken file.

## Consequences

- The layout now lives in Dux's untracked `~/.config/hypr/dms/outputs.lua`,
  not in git. The baseline in `monitors.lua` is the tracked copy. Update it
  when the desk changes, or a fresh home starts with stale positions.
- Choosing 240 Hz or "Auto" colour on the OLED in Dux has no effect: the
  guard rewrites it, and Dux's UI may show values that don't match what's
  live. To change those, edit the guard after reading the notes in
  `monitors.lua`.[^dux-shell-manual]
- Verified 2026-11-04. Offline, a stub-`hl` Lua harness ran the guard over
  240 Hz, `preferred`, bare `WxH`, `auto`, `hdr`, `hdredid`, 8-bit sRGB,
  disabled, connector-named and catch-all rules. Live, a staged `desc:` file
  moved DP-3, the guard held the OLED at 143.98 Hz / 10-bit / sRGB, a
  connector rule was ignored, and a syntax error fell back to the baseline.
- Landed in the commit that adds this record.

[^hyprland-rule-manager]: Hyprland v0.57.0 `MonitorRuleManager.cpp` (rule replace-by-name, last-match lookup)
[^dux-hyprland-service]: Dux Shell v2.1.0 `HyprlandService.qml` (buildOutputsLua, writeOutputsConfig)
[^dux-shell-manual]: docs/dux-shell.md — nebula's Dux Shell manual
[^hdr-notes]: docs/hdr-hyprland-june-2026.md — HDR and cm notes for the PG34WCDM
