---
type: Dual Module
title: Direnv
description: 'direnv + nix-direnv on both OSes; links nix-direnv''s stdlib into ~/.config/direnv/lib so `use flake` works, with a filename that deliberately sorts before direnv-nom''s wrapper.'
resource: modules/darwin/direnv.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

Installs `direnv` + `nix-direnv` and links nix-direnv's stdlib
(`share/nix-direnv/direnvrc`) to `~/.config/direnv/lib/nix-direnv.sh`, which
gives every `.envrc` the `use flake`/`use nix` implementation (nix-direnv's
internal `_nix()` function). The `nix-direnv.sh` name is a deliberate
alphabetical-ordering contract: it sorts before `zz-nom-wrapper.sh`, so
[direnv-nom](direnv-nom.md) loads afterwards and can redefine `_nix()`. The
shell hook and `direnv.toml` are stow-managed (`home/zsh`, `home/direnv`), not
part of this module — only the store-path link needs nix (see the
[store-path configs pattern](../patterns/store-path-configs.md)).

## Twin differences

Only how each class creates the `~/.config/direnv/lib/nix-direnv.sh` link
differs — see the
[store-path configs pattern](../patterns/store-path-configs.md). Package
lists are in sync (direnv + nix-direnv on both); see the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md).

Mounted ungated on every host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- darwin module: [`modules/darwin/direnv.nix`](../../modules/darwin/direnv.nix)
- NixOS module: [`modules/nixos/direnv.nix`](../../modules/nixos/direnv.nix)
- Stow package: [`home/direnv/`](../../home/direnv/) — see the [stow tree pattern](../patterns/stow-tree.md)
