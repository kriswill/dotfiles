---
type: Darwin Module
title: Direnv Nom
description: Wraps nix-direnv's _nix() to pipe `use flake` build logs through nix-output-monitor, with an nvd closure diff after successful builds.
resource: modules/darwin/direnv-nom.nix
tags: [darwin-module]
timestamp: '2026-06-28T18:27:01-07:00'
---

Wraps nix-direnv's internal `_nix()` function to pipe build logs through
nix-output-monitor (nom) during `use flake` in `.envrc`, and shows an nvd
closure diff after a successful build. The generated `zz-nom-wrapper.sh`
loads after [direnv](direnv.md)'s `nix-direnv.sh` (alphabetical order) so it
can redefine `_nix()`.

Mounted ungated on every darwin host (see the [host-mounted modules pattern](../patterns/host-mounted-modules.md)), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/direnv-nom.nix`](../../modules/darwin/direnv-nom.nix)
