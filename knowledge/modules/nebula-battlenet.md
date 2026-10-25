---
type: NixOS Module
title: Battle.net on nebula
description: 'nebula''s programs.battlenet settings: enables the GE-Proton Battle.net launcher on the umu entry''s existing prefix (compatdata/3082075026/pfx), so both entries share one WoW install.'
resource: modules/hosts/nebula/battlenet.nix
tags: [nixos-module, host-specific, gaming, proton]
generated: { by: claude-code/opus-5.5, at: 2026-10-25T14:00:00-07:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/battlenet/README.md
    title: 'flakes/battlenet/README.md (prefix layout, reusing an umu prefix)'
---

Turns on the [battlenet module](battlenet.md) with
`prefix = ".local/share/Steam/steamapps/compatdata/3082075026/pfx"`, which is
the prefix the stowed umu entry already uses, and the WoW icon from
`~/Downloads`. That prefix has umu's layout: umu passes the Wine prefix itself
as `STEAM_COMPAT_DATA_PATH` and leaves a `pfx -> .` link inside, so
`$prefix/pfx` resolves to the same directory and the version stamp is
`pfx/version`.[^subflake-readme]

Two launcher entries coexist:

- **"Battle.net"** is this module. It runs GE-Proton directly.
- **"Battle.net (umu)"** is the stowed
  [`Battle.net.desktop`](../../home/desktop-entries/.local/share/applications/Battle.net.desktop).
  It runs `umu-run` with Valve's Proton 11.0.

Alternating them flips `pfx/version` between `11.0-100` and `GE-Proton11-11`.
Neither parses as the other's format, so Proton takes its "invalid version"
path. That path upgrades the prefix in place and never reaches "Removing newer
prefix". [wowup](../packages/wowup.md) points into the same prefix's WoW
install. The WoW window rules in
[`window-rules.lua`](../../home/hyprland/.config/hypr/window-rules.lua) match
on title, so they cover both entries.

Host-specific file for [nebula](../hosts/nebula.md), merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/battlenet.nix`](../../modules/hosts/nebula/battlenet.nix)

[^subflake-readme]: `flakes/battlenet/README.md`: the NixOS module section (reusing an umu prefix)
