---
type: Dual Module
title: Herdr
description: 'herdr — terminal agent multiplexer (run several coding agents in persistent, SSH-reachable sessions); pinned on both OSes to an upstream preview flake tag for in-pane image rendering.'
resource: modules/darwin/herdr.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-28T01:39:41+00:00'
---

[herdr](https://herdr.dev) is a terminal multiplexer for coding agents: it
runs multiple agents side by side in one terminal, with persistent sessions
that survive detach and are reachable remotely over SSH. Both OSes are
**pinned to an upstream preview tag** via the `herdr` flake input (the repo
ships its own flake; built from source, no binary cache) for the CSI 14t/16t
pixel-size fix ([#835](https://github.com/herdrdev/herdr/issues/835)) that
stable 0.7.5 lacks — paired with `experimental.kitty_graphics = true` in the
stow `config.toml`, this enables in-pane image rendering (fastfetch/yazi; the
full story lives in [`docs/fastfetch.md`](../../docs/fastfetch.md)). Drop the
pin back to nixpkgs once a stable release carries the fix —
[herdr-update-check](herdr-update-check.md) is the daily reminder, and
dropping it now reverts **both** OSes at once.

Its `config.toml` is the `home/herdr/` [stow package](../patterns/stow-tree.md)
— adopted per-file because herdr keeps mutable runtime data (logs, sockets,
`session.json`) in the same `~/.config/herdr/` directory. The keybindings there
lean tmux-ward (`ctrl+space` prefix, `%`/`"` splits); `ctrl+h/j/k/l` pane focus
goes through [herdr-nav](../packages/herdr-nav.md), installed alongside herdr on
both OSes, so nvim keeps those keys inside its own splits — see the [vim-aware
pane navigation decision](../decisions/vim-aware-pane-navigation.md).

Darwin began as a plain nixpkgs entry in [user-packages](user-packages.md)
(too small to warrant its own module) and was promoted to a proper twin when
the preview-flake pin extended to darwin — both class modules now put the
input's package plus `herdr-nav` on `environment.systemPackages`, per the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md).

Mounted ungated on every host
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Darwin module: [`modules/darwin/herdr.nix`](../../modules/darwin/herdr.nix)
- NixOS module: [`modules/nixos/herdr.nix`](../../modules/nixos/herdr.nix)

## Citations

- [herdr project site](https://herdr.dev)
- [herdr repository](https://github.com/herdrdev/herdr)
