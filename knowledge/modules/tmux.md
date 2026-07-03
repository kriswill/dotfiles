---
type: Dual Module
title: Tmux
description: 'Installs tmux and generates plugins.conf — the one tmux file that must embed a /nix/store path (tmux-which-key''s rtp); tmux.conf and which-key''s config.yaml are stowed.'
resource: modules/darwin/tmux.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

Installs `pkgs.tmux` and generates `plugins.conf` via `writeText` (which-key
XDG enable + init-file touch + `run-shell ${whichKey.rtp}`), linked to
`~/.config/tmux/plugins.conf`. That file must embed the tmux-which-key
plugin's /nix/store path, so it can't live in stow — this is the canonical
worked example of the
[store-path configs pattern](../patterns/store-path-configs.md) that
AGENTS.md itself cites. `tmux.conf` and which-key's `config.yaml` are
stow-managed in `home/tmux/`.

## Twin differences

The generated `plugins.conf` is identical; only how each class links it into
`~/.config/tmux/` differs — see the
[store-path configs pattern](../patterns/store-path-configs.md). Package
lists in sync (tmux + the same plugin on both). See the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md).

Mounted ungated on every host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- darwin module: [`modules/darwin/tmux.nix`](../../modules/darwin/tmux.nix)
- NixOS module: [`modules/nixos/tmux.nix`](../../modules/nixos/tmux.nix)
- Stow package: [`home/tmux/`](../../home/tmux/) — see the [stow tree pattern](../patterns/stow-tree.md)
- Manual: [`docs/tmux.md`](../../docs/tmux.md)
