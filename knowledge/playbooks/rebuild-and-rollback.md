---
type: Playbook
title: Rebuild and Rollback
description: Apply, test-build, inspect, and roll back system generations.
tags: [darwin-rebuild, operations]
timestamp: '2026-07-02T00:00:00-07:00'
---

## Examples

```sh
darwin-rebuild switch --flake .              # apply (alias: nrs via nh)
nix build .#darwinConfigurations.k.system    # test build without applying
nix flake check                              # validate flake structure
nix eval .#darwinConfigurations.k.config.<path>   # inspect a config value
```

Inspect what a switch changed (commit bodies here conventionally include this):

```sh
nvd diff /nix/var/nix/profiles/system-{<prev>,<curr>}-link
```

Roll back:

```sh
darwin-rebuild --list-generations
darwin-rebuild switch --rollback             # previous generation
```

Notes:

- New files must be `git add`ed first — flakes only see tracked files (see
  [Dendritic module layout](../patterns/dendritic-modules.md)).
- [nh](../modules/nh.md) provides the friendlier `nh darwin switch` UX.
- Stow-tree configs apply without any rebuild at all — see the
  [stow tree pattern](../patterns/stow-tree.md).
