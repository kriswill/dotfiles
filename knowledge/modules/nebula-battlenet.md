---
type: NixOS Module
title: Battle.net on nebula
description: 'nebula''s programs.battlenet settings: enables the GE-Proton Battle.net launcher on the default prefix, ~/.local/share/battlenet, which holds the WoW install moved out of Steam''s compatdata/3082075026.'
resource: modules/hosts/nebula/battlenet.nix
tags: [nixos-module, host-specific, gaming, proton]
generated: { by: claude-code/opus-5.5, at: 2026-10-26T22:45:00-07:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/battlenet/README.md
    title: 'flakes/battlenet/README.md (prefix layout, reusing an umu prefix)'
---

Turns on the [battlenet module](battlenet.md) with its default prefix,
`~/.local/share/battlenet`, and the WoW icon from `~/Downloads`. "Battle.net"
is the only Battle.net entry.

The prefix's history:

- **Steam, then umu.** It started as Steam's
  `compatdata/3082075026` for a non-Steam shortcut, then served a stowed
  umu-launcher entry ("Battle.net (umu)", `umu-run` with Valve's Proton
  11.0). That entry and `umu-launcher` were removed on 2026-10-25, once this
  launcher kept one wineserver per prefix and stopped on Ctrl-C
  ([decision](../decisions/battlenet-one-wineserver.md)).
- **First GE-Proton start.** It moved the version stamp from Valve's
  `11.0-100` to `GE-Proton11-11`. Neither parses as the other's format, so
  Proton took its "invalid version" path, which upgrades in place and never
  reaches "Removing newer prefix".
- **Moved out of Steam's tree, the same day.** With nothing running, it was
  renamed to `~/.local/share/battlenet/pfx` (one filesystem, so instant
  despite the WoW install).[^subflake-readme] Two fixes came with it:
  - **Layout.** It was converted from umu's layout (`pfx -> .` link, Proton
    metadata inside the prefix) to Proton's, with `version`, `config_info`,
    `tracked_files`, `shadercache` and `gstreamer-1.0` next to `pfx/`.
  - **Steam links.** 30 links still pointed into Steam's
    `steamapps/common/Proton 11.0`, which GE-Proton's relink never touches.
    28 were .NET placeholders (wine-mono's `Microsoft.NET/Framework*`), now
    copies of GE-Proton's builtin files. The other 2 were `winegstreamer.dll`,
    which GE-Proton doesn't ship, and were deleted.
- **Checked afterwards.** Battle.net started from the new prefix on
  generation 185 with ntsync, and nothing in it points into
  `~/.local/share/Steam`. The Steam-era metadata is still in
  `~/.local/share/Steam/steamapps/compatdata/3082075026` (no `pfx/`).

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
- **CPUs:** `cpus = "0-5,12-17"` pins the session to the 9900X3D's 3D V-Cache
  CCD (96 MB L3; `6-11,18-23` share 32 MB). `amd_x3d_mode` stays `frequency`, so
  other work prefers the other CCD. On the first live run (affinity only),
  WoW set "all processors", which Wine reported as 24 CPUs. 76 of its 99
  threads (job pools, 22 QUIC workers, vkd3d queues) and `WowVoiceProxy.exe`
  moved to `0-23`. The launcher now also sets
  `WINE_CPU_TOPOLOGY=12:0,1,2,3,4,5,12,13,14,15,16,17`, so Wine reports those
  12 (WMI: 12 cores, 12 logical). The [btop overlay](../packages/btop.md)
  colours those CPUs' core labels, to watch the pinning live. Since
  2026-10-26, `confineSlices = [ "app.slice" ]` keeps other work off those
  CPUs while a session runs: `app.slice` (the terminals, Claude sessions, the
  sccache server that spawns the compilers, `wowdps-dev`) is held to
  `6-11,18-23`, and the game runs in `battlenet.slice`. `session.slice`
  (Hyprland and what it starts directly) is left alone
  ([decision](../decisions/battlenet-cpu-confinement.md)). Not yet seen live:
  that needs the rebuild, possibly a new login for the cpuset delegation,
  and a game launch.
- **Display:** native Wayland since 2026-10-25. `environment` sets
  `PROTON_ENABLE_WAYLAND = "1"` (WoW ran a little faster than under XWayland)
  and `PROTON_WAYLAND_MONITOR = "DP-3"`. Proton finds the primary monitor
  through xrandr's `primary` flag, which XWayland under Hyprland never sets,
  so Wine picked its own and WoW sized itself for the portrait DP-1. Classes
  are now `battle.net.exe` and `wow.exe`. WoW's exclusive fullscreen asked
  Hyprland to leave fullscreen, so the `wow-fullscreen` rule gained
  `suppress_event = "fullscreen maximize"` ([`docs/hyprland.md`](../../docs/hyprland.md),
  2026-10-25 entry). Battle.net's window lays out oddly for a few seconds,
  then settles. `PROTON_ENABLE_WAYLAND=0 battlenet` goes back to XWayland for
  one run.

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
