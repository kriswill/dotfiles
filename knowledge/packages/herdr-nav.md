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
  focused pane's id and its whole foreground process tree, parsed with `jq`.
  `--current` resolves server-side, which matters because herdr spawns the
  command without the `HERDR_*` pane env vars. `$HERDR_PANE_ID` is deliberately
  never read: a nested or oddly-launched server leaks the *outer* session's
  stale ids through to `[[keys.command]]` shells.
- vim/nvim/view/fzf anywhere in that tree (the same set tmux.conf matches with
  `ps`, so `git commit` opening `$EDITOR` counts) → `herdr pane send-keys` the
  chord to the pane; nvim walks its own splits and calls `herdr pane focus` only
  once it hits the edge (see [multiplexer navigation](../nvim/multiplexer.md)).
- otherwise → `herdr pane focus --direction …` on the id we just inspected, so
  the check and the move are about the same pane.

The vim test matches `argv0` and `argv[0]`'s basename — `name` is the kernel's
comm, truncated to 15 characters, and is only a last resort for entries carrying
no `argv`. Daemon invocations are excluded **per program**, because the flag
meaning "not a UI" differs: `--headless`/`--embed` for vim, `--listen` for fzf.
They are deliberately not pooled — `nvim --listen /tmp/sock` is an ordinary
interactive editor, and a blanket `--listen` test would stop forwarding to it.
This matters because `foreground_processes` is the whole process *group*, so a
pane running an agent or a dev script returns its LSP/formatter hosts and MCP
servers alongside the command the user is looking at, and forwarding the chord
to one of those types a stray backspace into the pane instead of switching it.
**Residual gap, stated
plainly:** herdr exposes no parent pid, so the tree can't be rebuilt and an
interactive vim running as a *background* child of the foreground job still
matches. tmux's `ps`-based `is_vim` has the same shape of gap — it additionally
filters process state (`^[^TXZ ]+`), which herdr does not expose.

A held key fires several detached copies at once, each resolving the focused
pane independently, so resolve-and-act is serialised behind an `mkdir` lock
(`flock(1)` does not exist on macOS). It self-heals after 300 ms and then
proceeds unlocked — dropping a keypress is worse than a rare double move.

Every failure path exits 0 silently: this runs on a keypress, and a busy or
missing socket must not spew errors into the session. That is also a contract
the binding depends on — `config.toml` chains
`herdr-nav left || … pane focus --direction left --current`, and because the
only non-zero exit is a usage error (2), the fallback fires just for
command-not-found, never when herdr-nav ran and forwarded the chord to vim.
That fallback exists because `config.toml` is a stow symlink that takes effect
as soon as herdr restarts, while herdr-nav only lands on the server's PATH after
a system rebuild; without it that window leaves all four keys dead. herdr runs
`[[keys.command]]` strings through `/bin/sh -lc` on both OSes and exports
`HERDR_BIN_PATH`, which is what makes the chain expressible at all.

`herdr` itself is pinned into the wrapper rather than taken from `PATH`, because
the herdr server spawns this and its `PATH` is not ours to control.

`focus_pane_*` keeps its `prefix+h/j/k/l` default as a direct, shim-free
fallback.

Rationale and the alternatives considered: [vim-aware pane navigation
decision](../decisions/vim-aware-pane-navigation.md).

Added per the [add-package playbook](../playbooks/add-package.md).

## Source

- Package: [`pkgs/herdr-nav.nix`](../../pkgs/herdr-nav.nix)
- Script: [`pkgs/herdr-nav.sh`](../../pkgs/herdr-nav.sh)
- Overlay: [`overlays/herdr-nav.nix`](../../overlays/herdr-nav.nix) — exposes/replaces `pkgs.herdr-nav`
- Installed alongside herdr on both OSes by the [herdr module twins](../modules/herdr.md): [`modules/nixos/herdr.nix`](../../modules/nixos/herdr.nix), [`modules/darwin/herdr.nix`](../../modules/darwin/herdr.nix)

## Citations

- [herdr project site](https://herdr.dev)
- [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) — the `is_vim` pattern this reimplements
