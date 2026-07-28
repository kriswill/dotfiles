---
type: Nix Package
title: Herdr Nav
description: herdr-nav — a keybinding shim that gives herdr the vim-aware pane switching tmux gets from is_vim + if-shell — forwarding ctrl+h/j/k/l to a pane running vim instead of moving pane focus.
resource: pkgs/herdr-nav.nix
tags: [package, herdr, nvim]
timestamp: '2026-07-28T12:30:00-07:00'
---

[herdr](../modules/herdr.md) has no conditional keybindings — a key bound to
`focus_pane_left` always moves pane focus, so nvim in a herdr pane would never
see `<C-h>`. herdr-nav is bound to `ctrl+h/j/k/l` instead, as a
`[[keys.command]]` shell command, and decides per keypress:

- `herdr pane process-info --current` — one socket round-trip returning both the
  focused pane's id and its whole foreground process tree. `--current` resolves
  server-side, which matters because herdr spawns the command without the
  `HERDR_*` pane env vars.
- vim/nvim/view/fzf anywhere in that tree (the same set tmux.conf matches with
  `ps`, so `git commit` opening `$EDITOR` counts) → `herdr pane send-keys` the
  chord to the pane; nvim walks its own splits and calls `herdr pane focus` only
  once it hits the edge (see [multiplexer navigation](../nvim/multiplexer.md)).
- otherwise → `herdr pane focus --direction …` directly.

Every failure path exits 0 silently: this runs on a keypress, and a busy or
missing socket must not spew errors into the session. `herdr` itself is pinned
into the wrapper rather than taken from `PATH`, because the herdr server spawns
this and its `PATH` is not ours to control.

`focus_pane_*` keeps its `prefix+h/j/k/l` default as a direct, shim-free
fallback.

Rationale and the alternatives considered: [vim-aware pane navigation
decision](../decisions/vim-aware-pane-navigation.md).

Added per the [add-package playbook](../playbooks/add-package.md).

## Source

- Package: [`pkgs/herdr-nav.nix`](../../pkgs/herdr-nav.nix)
- Script: [`pkgs/herdr-nav.sh`](../../pkgs/herdr-nav.sh)
- Overlay: [`overlays/herdr-nav.nix`](../../overlays/herdr-nav.nix) — exposes/replaces `pkgs.herdr-nav`
- Installed alongside herdr on both OSes: [`modules/nixos/herdr.nix`](../../modules/nixos/herdr.nix), [`modules/darwin/user-packages.nix`](../../modules/darwin/user-packages.nix)

## Citations

- [herdr project site](https://herdr.dev)
- [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) — the `is_vim` pattern this reimplements
