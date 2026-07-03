---
type: Playbook
title: Rebuild and Rollback
description: Apply, test-build, inspect, and roll back system generations on both OSes.
tags: [darwin-rebuild, nixos-rebuild, operations]
timestamp: '2026-07-03T12:00:00-07:00'
---

## Examples

The `nr*` helpers exist on every host of both OSes:

```sh
nrs             # apply: nh darwin switch (Macs) / nh os switch (nebula); sudo at activation
nrb             # build only, no root — safe anywhere
nrt             # darwin: build + run system.checks, no activation; nixos: activate without a bootloader entry
```

Raw invocations and evaluation checks:

```sh
darwin-rebuild switch --flake .              # macOS
sudo nixos-rebuild switch --flake .#nebula   # nebula — cd into the real checkout first:
                                             #   --flake <path> does not follow the ~/src/dotfiles symlink
nix flake check                              # validate flake + build the current system's host checks
                                             #   (other-system checks eval only)
nix eval .#darwinConfigurations.k.config.<path>        # inspect a darwin config value
nix eval .#nixosConfigurations.nebula.config.<path>    # inspect a nixos config value
nix eval .#nixosConfigurations.nebula.config.system.build.toplevel.drvPath
                                             # full cross-eval of nebula from a Mac (the pre-hardware gate)
```

The `nr*` helpers are real executables from [nh](../modules/nh.md) (not shell
aliases) — `nh darwin *` on Macs, `nh os *` on nebula
(`modules/darwin/nh.nix` ↔ `modules/nixos/nh.nix`) — so they also work in
non-interactive shells (agent harnesses, scripts); extra args pass through
(`nrs -v`, `nrb --dry`). On nebula they resolve the flake dir with
`readlink -f`, dodging the symlinked-checkout gotcha above.

Inspect what a switch changed (commit bodies here conventionally include this):

```sh
nvd diff /nix/var/nix/profiles/system-{<prev>,<curr>}-link
```

Roll back:

```sh
darwin-rebuild --list-generations
darwin-rebuild switch --rollback             # previous generation (macOS)
nixos-rebuild list-generations
sudo nixos-rebuild switch --rollback         # previous generation (nebula)
```

Notes:

- New files must be `git add`ed first — flakes only see tracked files (see
  [Dendritic module layout](../patterns/dendritic-modules.md)).
- [nh](../modules/nh.md) provides the friendlier `nh darwin switch` /
  `nh os switch` UX.
- Stow-tree configs apply without any rebuild at all — see the
  [stow tree pattern](../patterns/stow-tree.md).
