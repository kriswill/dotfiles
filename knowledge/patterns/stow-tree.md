---
type: Pattern
title: Stow Tree
description: Plain config files live in home/ as GNU Stow packages symlinked into $HOME, pointing at the live repo so edits apply without a rebuild.
resource: modules/darwin/dotfiles-stow.nix
tags: [stow, dotfiles, symlinks]
timestamp: '2026-07-02T00:00:00-07:00'
---

Config files that don't need Nix evaluation live under `home/` as one GNU Stow
package per directory, each mirroring `$HOME` (e.g.
`home/tmux/.config/tmux/tmux.conf`). The
[dotfiles-stow](../modules/dotfiles-stow.md) module restows every package
during system activation.

Why it's shaped this way:

- **Symlinks point at the live repo checkout, not `${./home}` in the store** —
  editing a tracked config applies immediately, no rebuild; the links stay
  stable across generations; and `stow --adopt` can pull live edits back into
  the repo.
- `--no-folding` links individual files (not directories), so apps can write
  sibling files without landing in the repo.
- Conflicts are logged and skipped per package; stale links self-heal on the
  next activation.
- Adding a package = adding a directory under `home/` — no Nix edit needed.

Capture and round-trip workflows are in the
[adopt-dotfile playbook](../playbooks/adopt-dotfile.md), using
[dots-adopt](../packages/dots-adopt.md). Files that must embed `/nix/store`
paths can't live here — see
[store-path-embedding configs](store-path-configs.md).
