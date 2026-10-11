---
type: Dual Module
title: User Packages
description: 'The everyday CLI toolbox — on darwin the primary user''s per-user package list (bat/fzf/ripgrep … lazygit, uv, the Bun/Node runtimes); on nebula the re-enabled snowglobe defaults (bat, ripgrep, lazygit, yazi, jq, zip, brightnessctl, nix-index-database/comma) the stow configs call by name.'
resource: modules/darwin/user-packages.nix
tags: [darwin-module, nixos-module]
generated: { by: okflight/0.4.0, at: 2026-07-04T00:00:00-07:00 }
---

The darwin per-user package list (`users.users.k.packages`): the everyday
CLI toolbox — bat, fzf, ripgrep, lazygit, jq, just, uv, nix-tree, … —
installed for the primary user rather than system-wide. It is also the
darwin provisioner of the JS runtimes: [bun](../runtimes/bun.md) and
`nodejs_24` live here, where NixOS provides them system-wide via
[node-runtime](node-runtime.md) instead (there is no darwin twin of that
module); [neovim](neovim.md)'s darwin twin separately carries a plain
`nodejs` in its system-wide tool list for LSP servers.

Mounted ungated on every darwin host (see the [host-mounted modules pattern](../patterns/host-mounted-modules.md)), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Twin differences

The NixOS twin (added 2026-10-11) installs nothing by package list. Until
snowglobe-factory's 2026-10 debloat (commit 1f9de238) snowglobe enabled
bat, lazygit, ripgrep, yazi, jq, zip, brightnessctl and
nix-index-database/comma by default, and the stow tree depends on them by
bare name: `cat`→bat and `lg`→lazygit ([zsh](zsh.md) aliases), `rg` in the
[git](git.md) config, snacks' lazygit keymap in [neovim](neovim.md), the
yazi `y` wrapper (nebula takes yazi's config from snowglobe's module since
`home/yazi` is skip-listed on nixos — see the [stow OS skip-list
decision](../decisions/stow-os-skip-lists.md)), and jq/brightnessctl in the
[hyprland](hyprland.md) binds. The twin flips those `programs.*.enable`
options back on (nixpkgs modules for bat/lazygit, snowglobe's program
modules for the rest) and imports the `nix-index-database` flake input —
snowglobe dropped that input too — for the prebuilt command-not-found db
and comma-with-db (`, prog`; [determinate](determinate.md) overlays comma to
use the system nix). Tools other nixos modules already install (eza/fzf/fd in
[zsh](zsh.md), the git suite, the nvim toolchain, Bun/Node via
[node-runtime](node-runtime.md)) are not repeated.

## Source

- darwin module: [`modules/darwin/user-packages.nix`](../../modules/darwin/user-packages.nix)
- NixOS module: [`modules/nixos/user-packages.nix`](../../modules/nixos/user-packages.nix)
