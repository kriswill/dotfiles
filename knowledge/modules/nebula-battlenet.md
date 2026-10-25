---
type: NixOS Module
title: Battle.net on nebula
description: 'nebula''s programs.battlenet settings: enables the GE-Proton Battle.net launcher on the prefix umu-launcher used before it was dropped (compatdata/3082075026/pfx), which holds the WoW install.'
resource: modules/hosts/nebula/battlenet.nix
tags: [nixos-module, host-specific, gaming, proton]
generated: { by: claude-code/opus-5.5, at: 2026-10-25T16:00:00-07:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/battlenet/README.md
    title: 'flakes/battlenet/README.md (prefix layout, reusing an umu prefix)'
---

Turns on the [battlenet module](battlenet.md) with
`prefix = ".local/share/Steam/steamapps/compatdata/3082075026/pfx"` and the
WoW icon from `~/Downloads`. "Battle.net" is the only Battle.net entry.

The prefix came from Steam and then served a stowed umu-launcher entry
("Battle.net (umu)", `umu-run` with Valve's Proton 11.0). That entry and
`umu-launcher` were removed on 2026-10-25, once this launcher kept one
wineserver per prefix and stopped on Ctrl-C
([decision](../decisions/battlenet-one-wineserver.md)). The prefix keeps umu's
layout: umu passed the Wine prefix itself as `STEAM_COMPAT_DATA_PATH` and left
a `pfx -> .` link inside it, so `$prefix/pfx` resolves to the same directory
and the version stamp is `pfx/version`.[^subflake-readme] Its first GE-Proton
start moved the stamp from Valve's `11.0-100` to `GE-Proton11-11`. Neither
parses as the other's format, so Proton took its "invalid version" path, which
upgrades in place and never reaches "Removing newer prefix".

WoW on nebula, from a logged session on 2026-10-25 (the stack and the log
lines that are normal are in the README's "What WoW runs on"):[^subflake-readme]

- **Graphics:** Direct3D 12 through vkd3d-proton on NVIDIA's 595.104.02
  Vulkan driver (`libGLX_nvidia`, `libnvidia-glcore`, `libnvidia-rtcore`,
  `libcuda`). DXVK-NVAPI answers WoW's NVIDIA queries.
- **Audio:** PipeWire's PulseAudio server. Wine ignores the output device's
  `aux2`–`aux5` channels.
- **Sync:** fsync at first: the `ntsync` module wasn't loaded. Since
  generation 184, [ntsync](ntsync.md) loads it, and the wineserver reports
  `ntsync: up and running.`; WoW holds 101 ntsync objects.
- **Shaders:** the first session rebuilt vkd3d-proton's pipeline cache
  (`_retail_/vkd3d-proton.cache`), which the umu and Valve Proton runs had
  written for a different build.

[wowup](../packages/wowup.md) points into the same prefix's WoW install. The
WoW window rules in
[`window-rules.lua`](../../home/hyprland/.config/hypr/window-rules.lua) match
on title, not class.

Host-specific file for [nebula](../hosts/nebula.md), merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/battlenet.nix`](../../modules/hosts/nebula/battlenet.nix)

[^subflake-readme]: `flakes/battlenet/README.md`: the NixOS module section (reusing an umu prefix)
