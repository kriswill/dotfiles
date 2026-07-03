---
type: Dual Module
title: Ghostty
description: 'Ghostty terminal — each OS installs it its own way and generates its half of the split config (`config-file = ?os.conf`); the shared config is stowed.'
resource: modules/darwin/ghostty.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

Ghostty terminal with a **split config**: the stow-managed shared config
(`home/ghostty/`) ends with `config-file = ?os.conf` (the `?` tolerates
absence), so each OS module generates its own `os.conf` whose keys load last
and win. That generated half is the per-class store-path file (see the
[store-path configs pattern](../patterns/store-path-configs.md)).

## Twin differences

Install method differs by design — no shared package list at all. Darwin
installs the app via a Homebrew cask, exports `TERMINFO_DIRS`, and symlinks
`~/.terminfo` to the app bundle's terminfo so SSH-ing to other machines
works; its `os.conf` sets a 141x45 window, hidden titlebar, font-size 18, and
a global quick-terminal keybind. NixOS enables the upstream
`programs.ghostty.enable` module; its `os.conf` sets
`window-decoration = none`,
`gtk-custom-css = corners.css`, `window-theme = ghostty`,
`confirm-close-surface = false`, background `#0e0e0e` at 0.92 opacity,
font-size 14, and `theme = noctalia` (recolored by
[Noctalia](users-k-noctalia.md) templates). See the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md).

Mounted ungated on every host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- darwin module: [`modules/darwin/ghostty.nix`](../../modules/darwin/ghostty.nix)
- NixOS module: [`modules/nixos/ghostty.nix`](../../modules/nixos/ghostty.nix)
- Stow package: [`home/ghostty/`](../../home/ghostty/) — see the [stow tree pattern](../patterns/stow-tree.md)
