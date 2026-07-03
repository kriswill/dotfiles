---
type: Dual Module
title: Dotfiles Stow
description: 'Restows every home/ package into $HOME on each rebuild via the shared lib/stow-restow-script.nix builder — live-repo symlinks, self-healing, per-OS skip lists.'
resource: modules/darwin/dotfiles-stow.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

Restows every package directory under the live repo's `home/` tree into
`$HOME` on every rebuild — never a `${./home}` store copy, so links stay
stable across rebuilds and the adopt workflow works (see the
[stow tree pattern](../patterns/stow-tree.md)). The script (from the shared
builder [`lib/stow-restow-script.nix`](../../lib/stow-restow-script.nix))
canonicalizes the stow dir, self-heals links that reach repo files through a
non-canonical convenience symlink, then runs `stow --no-folding --restow` per
package with per-package conflict tolerance (log + skip, never abort). Also
installs `stow` and the `dots-adopt` capture helper. The whole thing runs in
a subshell so a stray `exit` can't abort the rest of activation — the
hard-won lesson from the June-06 bootloader incident (manual below).

## Twin differences

Both classes consume the same builder with different arguments — darwin:
`home=/Users/k`, `runAsUser = sudo -u k --set-home`, hook = `postActivation`
at `mkOrder 1500` (the anchor that generated
[store-path configs](../patterns/store-path-configs.md) link after); nixos:
`home=/home/k`, `runAsUser = runuser -u k -- env
HOME=…`, hook = named activation script `stowDotfiles` with
`deps = ["users"]`. Each carries a skip list of the other OS's 7 packages —
intentionally different lists that mirror-comment each other, not drift (see
the [skip-lists decision](../decisions/stow-os-skip-lists.md) and the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md)).

Mounted ungated on every host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- darwin module: [`modules/darwin/dotfiles-stow.nix`](../../modules/darwin/dotfiles-stow.nix)
- NixOS module: [`modules/nixos/dotfiles-stow.nix`](../../modules/nixos/dotfiles-stow.nix)
- Shared builder: [`lib/stow-restow-script.nix`](../../lib/stow-restow-script.nix)
- Manual: [`docs/bootloader-issues-jun-06.md`](../../docs/bootloader-issues-jun-06.md)
