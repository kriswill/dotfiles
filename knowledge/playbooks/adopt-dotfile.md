---
type: Playbook
title: Adopt a Dotfile Into the Stow Tree
description: Capture an existing $HOME config into home/, or pull live edits of a tracked file back into the repo.
tags: [stow, dotfiles]
timestamp: '2026-07-03T12:00:00-07:00'
---

Per the [stow tree pattern](../patterns/stow-tree.md), each dir under `home/`
is one stow package mirroring `$HOME`.

## Examples

Capture an existing file into a (new or existing) package with
[dots-adopt](../packages/dots-adopt.md):

```sh
dots-adopt <pkg> <relpath-under-$HOME>
# e.g. dots-adopt btop .config/btop/btop.conf
```

Pull live edits of an already-tracked file back into the repo (overwrites the
repo copy — check `git diff` after):

```sh
stow -d ~/src/dotfiles/home -t ~ --no-folding --adopt <pkg>
```

Adding a whole new package usually needs no Nix change — create the directory
and the next activation (or a manual restow) links it, **on both OSes** by
default; an OS-scoped package additionally needs a skip-list entry in the
other OS's `modules/<class>/dotfiles-stow.nix` (see the
[per-OS skip lists decision](../decisions/stow-os-skip-lists.md)). Files that
must embed
`/nix/store` paths don't belong here; see
[store-path-embedding configs](../patterns/store-path-configs.md).
