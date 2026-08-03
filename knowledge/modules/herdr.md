---
type: NixOS Module
title: Herdr
description: 'herdr — terminal agent multiplexer (run several coding agents in persistent, SSH-reachable sessions); on NixOS pinned to an upstream preview flake tag, on darwin from nixpkgs.'
resource: modules/nixos/herdr.nix
tags: [nixos-module]
timestamp: '2026-07-28T01:39:41+00:00'
---

[herdr](https://herdr.dev) is a terminal multiplexer for coding agents: it
runs multiple agents side by side in one terminal, with persistent sessions
that survive detach and are reachable remotely over SSH. On NixOS it is
**pinned to an upstream preview tag** via the `herdr` flake input (the repo
ships its own flake; built from source, no binary cache) for the CSI 14t/16t
pixel-size fix ([#835](https://github.com/herdrdev/herdr/issues/835)) that
stable 0.7.5 lacks — paired with `experimental.kitty_graphics = true` in the
stow `config.toml`, this enables in-pane image rendering (fastfetch/yazi; the
full story lives in [`docs/fastfetch.md`](../../docs/fastfetch.md)). Drop the
pin back to nixpkgs once a stable release carries the fix. Darwin still
installs unmodified from nixpkgs.

Its `config.toml` is the `home/herdr/` [stow package](../patterns/stow-tree.md)
— adopted per-file because herdr keeps mutable runtime data (logs, sockets,
`session.json`) in the same `~/.config/herdr/` directory. The keybindings there
lean tmux-ward (`ctrl+space` prefix, `%`/`"` splits); `ctrl+h/j/k/l` pane focus
goes through [herdr-nav](../packages/herdr-nav.md), installed alongside herdr on
both OSes, so nvim keeps those keys inside its own splits — see the [vim-aware
pane navigation decision](../decisions/vim-aware-pane-navigation.md).

Deliberately **not** a cross-OS twin pair: the NixOS module puts it on
`environment.systemPackages`, while on darwin it is one entry in the
[user-packages](user-packages.md) list — a plain-package install too small to
warrant its own darwin module.

Mounted ungated on every NixOS host
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- NixOS module: [`modules/nixos/herdr.nix`](../../modules/nixos/herdr.nix)
- darwin install: [`modules/darwin/user-packages.nix`](../../modules/darwin/user-packages.nix)

## Citations

- [herdr project site](https://herdr.dev)
- [herdr repository](https://github.com/ogulcancelik/herdr)
