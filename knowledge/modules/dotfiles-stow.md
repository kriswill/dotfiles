---
type: Dual Module
title: Dotfiles Stow
description: 'Restows every home/ package into $HOME on each rebuild via the shared lib/stow-restow-script.nix builder — live-repo symlinks, self-healing, per-OS skip lists.'
resource: modules/darwin/dotfiles-stow.nix
tags: [darwin-module, nixos-module]
generated: { by: okflight/0.4.0, at: 2026-07-03T12:00:00-07:00 }
---

Restows every package directory under the live repo's `home/` tree into
`$HOME` on every rebuild — never a `${./home}` store copy, so links stay
stable across rebuilds and the adopt workflow works (see the
[stow tree pattern](../patterns/stow-tree.md)). The script (from the shared
builder [`lib/stow-restow-script.nix`](../../lib/stow-restow-script.nix))
canonicalizes the stow dir, self-heals links that reach repo files through a
non-canonical convenience symlink, then runs `stow --no-folding --restow` per
package with per-package conflict tolerance (report + skip, never abort). It
reports as an NDJSON event stream on stderr (`begin`/`skip`/`heal`/`ok`/
`conflict`/`end`), which [nrs2](nrs2.md) renders as a live progress line
and a one-line summary. See the
[NDJSON activity decision](../decisions/stow-ndjson-activity.md). Stow
runs with `--ignore='\.cache'` and `--ignore='\.DS_Store'`: sudo'd tools
occasionally drop root-owned droppings *inside* a stow package (a root-owned
`.cache/` in `home/fastfetch` was unreadable to the user-level stow, which
errored and silently skipped the whole package on every restow, 2026-08-03) —
ignore matching is by name before stow opens the dir, so such droppings can't
take the package down. Git ignores them at any depth too (`**/.cache/` in
`.gitignore`). Also
installs `stow` and the `dots-adopt` capture helper. The whole thing runs in
a subshell so a stray `exit` can't abort the rest of activation — the
hard-won lesson from the June-06 bootloader incident (manual below).

## Twin differences

Both classes consume the same builder with different arguments. The builder
puts the whole restow in one `writeShellScript` that `runAsUser` runs once
(nothing in it needs root). The Mac's slow restow (2.55 s for 21 packages)
was not the per-package `sudo`, which costs 0.03 s, but the self-heal's
per-file `readlink`/`dirname`/`realpath` subshells, about 10 ms per stowed
file on macOS (nvim's 77 files: 875 ms). Links are now resolved with one
batched `readlink -z` and `realpath -z` per package, and the clock is bash's
`EPOCHREALTIME`. Measured on the Mac against the same home: 2.55 s → 0.80 s
(nvim 54 ms). A restow that dies is reported as a
`failed` event, never fatal to activation. Darwin: `home=/Users/k`,
`runAsUser = sudo -u k --set-home`, `fold = [ "karabiner" ]` (stowed without
`--no-folding`, so `~/.config/karabiner` is one directory link, as
Karabiner-Elements' docs require for it to notice changes; its
`automatic_backups/` is gitignored), hook = `postActivation`
at `mkOrder 1500` (the anchor that generated
[store-path configs](../patterns/store-path-configs.md) link after); nixos:
`home=/home/k`, `runAsUser = setpriv --reuid=k … -- env
HOME=…` (not runuser, which opened a PAM session per package and flooded
the streamed rebuild output), hook = named activation script `stowDotfiles` with
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
