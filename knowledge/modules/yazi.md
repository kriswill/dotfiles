---
type: Darwin Module
title: Yazi
description: 'yazi — the Rust terminal file manager; here installed system-wide with stow-managed config, a generated kanagawa-dragon flavor, and a mix of store-linked and vendored preview plugins.'
resource: modules/darwin/yazi/default.nix
tags: [darwin-module]
timestamp: '2026-06-28T17:04:23-07:00'
---

Installs `yazi` plus `imagemagick` (required by the `font-dark` previewer)
and wires config from three sources:

- **Stow tree** (`home/yazi/.config/yazi/…`): yazi.toml, theme.toml,
  init.lua, and the user-owned plugins — `font-dark` and the vendored
  `faster-piper` fork (see
  [the vendoring decision](../decisions/vendor-faster-piper-fork.md):
  upstream's cache generation let interrupted markdown previews cache
  blank output; the fork renders in a detached daemon with atomic install).
- **Activation script** (order 1600, after dotfiles-stow at 1500): links
  the store-only pieces under `~/.config/yazi/{plugins,flavors}` — the
  `git` plugin (`pkgs.yaziPlugins.git`), the `types.yazi` LuaCATS stubs,
  and the kanagawa-dragon flavor generated from `lib.kanagawa`
  (`_themes/kanagawa-dragon`).
- **PATH expectations**: previews shell out to `glow` (markdown, styled by
  the stowed kanagawa glow theme) and `bat` (code), both installed
  elsewhere (core.nix).

Mounted ungated on every darwin host (see the [host-mounted modules
pattern](../patterns/host-mounted-modules.md)), auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/yazi/default.nix`](../../modules/darwin/yazi/default.nix)
- Stow package: [`home/yazi/`](../../home/yazi/) — see the [stow tree pattern](../patterns/stow-tree.md)

## Citations

- [yazi.toml configuration reference](https://yazi-rs.github.io/docs/configuration/yazi) — previewer/preloader rules
- [alberti42/faster-piper.yazi](https://github.com/alberti42/faster-piper.yazi) — upstream of the vendored fork
