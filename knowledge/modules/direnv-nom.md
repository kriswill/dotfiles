---
type: Dual Module
title: Direnv Nom
description: Wraps nix-direnv's _nix() to pipe `use flake` build logs through nix-output-monitor, with an nvd closure diff after successful builds; wrapper text shared via lib/direnv-nom-wrapper.nix.
resource: modules/darwin/direnv-nom.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

Wraps nix-direnv's internal `_nix()` function to pipe build logs through
nix-output-monitor (nom) during `use flake` in `.envrc`, and shows a closure
diff after a successful build — selectable via `programs.direnv-nom.diff`
(`nvd` default, `native` for `nix store diff-closures`, `none` to disable; a
behavior setting on a universal module, not a gate — both classes declare the
same option). The generated `zz-nom-wrapper.sh` loads after
[direnv](direnv.md)'s `nix-direnv.sh` (alphabetical order) so it can redefine
`_nix()`.

Only the `print-dev-env` subcommand is wrapped (everything else passes
through to the real nix); the wrapper sniffs the `--profile` argument to
detect a flake-profile change and compute the diff against the previous
generation. It installs no packages: nom, nvd, and coreutils are baked in as
/nix/store paths — the reason this can't be a stow file (see the
[store-path configs pattern](../patterns/store-path-configs.md)).

## Twin differences

The wrapper text is a single shared builder,
[`lib/direnv-nom-wrapper.nix`](../../lib/direnv-nom-wrapper.nix) (parameter:
`diffCmd`), so the twins can't drift on content; each class links the
generated `zz-nom-wrapper.sh` its own way — see the
[store-path configs pattern](../patterns/store-path-configs.md) and the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md).

Mounted ungated on every host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- darwin module: [`modules/darwin/direnv-nom.nix`](../../modules/darwin/direnv-nom.nix)
- NixOS module: [`modules/nixos/direnv-nom.nix`](../../modules/nixos/direnv-nom.nix)
- Shared builder: [`lib/direnv-nom-wrapper.nix`](../../lib/direnv-nom-wrapper.nix)
