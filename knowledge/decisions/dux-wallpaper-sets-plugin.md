---
type: Decision
title: Add Wallpaper Sets to Dux as a Stowed User Plugin, Not a Patch
description: 'Dux Shell already stores a wallpaper per display but has no way to save a combination and switch to it, so a small composite plugin (Dash tab + `dms ipc` daemon) adds named sets through the supported plugin API. It is deployed from the stow tree into ~/.config/dms/plugins so edits are live, rather than patching the package or using programs.dux-shell.plugins.'
tags: [nixos, hyprland, desktop-shell, dux-shell]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-11-04T15:50:00-08:00 }
sources:
  - id: dux-plugin-docs
    resource: https://github.com/duxlabs-dev/dux-shell/blob/master/quickshell/PLUGINS/README.md
    title: Dux Shell plugin system (quickshell/PLUGINS/README.md)
  - id: dux-wallpaper-ipc
    resource: https://github.com/duxlabs-dev/dux-shell/blob/v2.0.0/quickshell/Services/WallpaperCyclingService.qml
    title: Dux Shell v2.0.0 `WallpaperCyclingService.qml` (the `wallpaper` IPC target, incl. setFor)
  - id: nixpkgs-dux-shell-module
    resource: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/programs/wayland/dux-shell.nix
    title: nixpkgs `nixos/modules/programs/wayland/dux-shell.nix`
  - id: dux-shell-manual
    resource: ../../docs/dux-shell.md
    title: docs/dux-shell.md — nebula's Dux Shell manual
---

**Where:** [users-k-dux-shell](../modules/users-k-dux-shell.md),
[stow tree](../patterns/stow-tree.md) package `home/dux-shell/`.

## Context

nebula has two differently shaped monitors: DP-1 is rotated to portrait and
DP-3 is landscape. Dux 2.0 already supports a separate wallpaper per display.
Turn on Settings → Wallpaper → "Separate per display", or call
`dms ipc call wallpaper setFor <output> <path>`.[^dux-wallpaper-ipc] What it
lacks is a way to save a combination and switch to it later. The Dash
Wallpapers tab only sets the image for the display the dash is open on.

The options were to patch Dux's QML (the package embeds it in the Go binary
and extracts it at runtime, so a patch means overriding the nixpkgs build and
re-checking it on every bump), or to write a plugin. Dux plugins can import
`qs.Common`, so a plugin can call the same `SessionData.setMonitorWallpaper()`
the built-in tab uses. A plugin can also add a Dash tab and register
`IpcHandler`s.[^dux-plugin-docs]

## Decision

- **A composite plugin, `wallpaperSets`**, in
  `home/dux-shell/.config/dms/plugins/WallpaperSets/`:
  - `sets.js` holds the shared, pure logic.
  - `WallpaperSetsTab.qml` is a Dash tab. It shows the current displays and
    has a field for saving them under a name. Clicking a saved set applies
    it; the trash icon removes it.
  - `WallpaperSetsDaemon.qml` registers the IPC target
    `dms ipc call wallpaperSets list|current|show|apply|save|remove|next|prev`,
    which keybinds can use.
- **Snapshot sets.** A set records what each output shows when it is saved
  (`{output: path}`) and that output's geometry, so its preview keeps the
  physical order when a monitor is unplugged. Sets are stored through
  `PluginService.savePluginData` in `~/.config/dms/plugin_settings.json`.
  Applying a set mirrors `wallpaper setFor`: it turns on per-display mode,
  then sets each connected output and clears that output's cycling folder.
- **Deployed by stow, not `programs.dux-shell.plugins`.** The nixpkgs option
  installs plugins as store paths under `/etc/xdg/quickshell/dms-plugins/`,
  which Dux also scans.[^nixpkgs-dux-shell-module] That suits pinned
  third-party plugins (the manual's advice[^dux-shell-manual]). Code
  maintained in this repo is better as a stow link: edit the file, then run
  `dms ipc call plugins reload wallpaperSets`, with no rebuild. The package
  is on darwin's skip-list.

## Consequences

- Enabling it is runtime state. A composite plugin loads only after it is
  enabled (`dms ipc call plugins enable wallpaperSets`, or Settings →
  Plugins), and the enabled flag is kept in the untracked
  `plugin_settings.json` along with the saved sets.
- If `~/.config/dms/plugins/` did not exist when the shell started, Dux's
  folder watcher never sees it appear. The first install needs
  `systemctl --user restart dms`.
- Because sets only pass paths through, they work for any wallpaper Dux can
  render, including 2.1.0's video wallpapers (nebula overrides nixpkgs'
  2.0.0 to get them, see [users-k-dux-shell](../modules/users-k-dux-shell.md)).
  Tiles use Dux's per-video poster frame when its `VideoWallpaperService`
  exists. A `typeof` guard keeps the plugin working on 2.0.
- Edits to `sets.js` need a `dms` restart, because `plugins reload` keeps the
  engine's cached copy of the JS library. QML edits only need a reload.
- A set that names an unplugged output applies to the outputs that are
  connected and lists the missing ones. Matugen colours regenerate once, when
  the theme-source output changes.
- Uses what upstream documents as the supported plugin API (`qs.Common`,
  `qs.Services`, `qs.Modules.Plugins`), plus the `qs.Modules.DDash` imports
  that its Dash plugin docs and examples use.[^dux-plugin-docs] A Dux bump
  should not need code changes. The Dash widgets (`Card`, `DTextField`) are
  not covered by that promise and could still change.
- Landed in the commit that adds this record.

[^dux-plugin-docs]: Dux Shell plugin system (quickshell/PLUGINS/README.md)
[^dux-wallpaper-ipc]: Dux Shell v2.0.0 `WallpaperCyclingService.qml` (the `wallpaper` IPC target, incl. setFor)
[^nixpkgs-dux-shell-module]: nixpkgs `nixos/modules/programs/wayland/dux-shell.nix`
[^dux-shell-manual]: docs/dux-shell.md — nebula's Dux Shell manual
