---
type: Pattern
title: Stow Tree
description: Plain config files live in home/ as GNU Stow packages symlinked into $HOME — one tree shared by macOS and NixOS, pointing at the live repo so edits apply without a rebuild.
resource: modules/darwin/dotfiles-stow.nix
tags: [stow, dotfiles, symlinks]
timestamp: '2026-07-11T12:40:00-07:00'
---

Config files that don't need Nix evaluation live under `home/` as one GNU Stow
package per directory, each mirroring `$HOME` (e.g.
`home/tmux/.config/tmux/tmux.conf`). The tree is **shared by both OSes**: each
OS's [dotfiles-stow](../modules/dotfiles-stow.md) twin
(`modules/{darwin,nixos}/dotfiles-stow.nix`, script body shared via
[`lib/stow-restow-script.nix`](../../lib/stow-restow-script.nix) per the
[cross-OS twins pattern](cross-os-module-twins.md)) restows every package
during system activation — except the packages on its OS skip list (mirrored
lists with why-comments; see the
[skip-lists decision](../decisions/stow-os-skip-lists.md)). The twins differ
only in paths, skip lists, and the run-as-user command (`sudo -u k --set-home`
on darwin, `runuser` on nixos).

Why it's shaped this way:

- **Symlinks point at the live repo checkout, not `${./home}` in the store** —
  editing a tracked config applies immediately, no rebuild; the links stay
  stable across generations; and `stow --adopt` can pull live edits back into
  the repo.
- `--no-folding` links individual files (not directories), so apps can write
  sibling files without landing in the repo.
- Conflicts are logged and skipped per package; stale links self-heal on the
  next activation.
- Adding a package = adding a directory under `home/` — deployed on **both
  OSes** by default; an OS-scoped package additionally needs a skip-list entry
  in the other OS's dotfiles-stow module.

Capture and round-trip workflows are in the
[adopt-dotfile playbook](../playbooks/adopt-dotfile.md), using
[dots-adopt](../packages/dots-adopt.md). Three kinds of file can't live here:
files that must embed `/nix/store` paths
([store-path-embedding configs](store-path-configs.md)); files their app
rewrites via atomic rename, which destroys the symlink on the first save
([snapshot-synced configs](snapshot-synced-configs.md)); and secret material —
the tree is published, so e.g. private ssh `Host` entries live in a sops file
deployed alongside the public config instead
([ssh-private-hosts decision](../decisions/ssh-private-hosts.md)).
