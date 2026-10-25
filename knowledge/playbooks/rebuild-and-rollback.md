---
type: Playbook
title: Rebuild and Rollback
description: 'Apply, test-build, inspect, and roll back system generations on both OSes.'
tags: [darwin-rebuild, nixos-rebuild, operations]
generated: { by: okflight/0.4.0, at: 2026-07-03T12:00:00-07:00 }
---

## Examples

The `nr*` helpers exist on every host of both OSes:

```sh
nrs             # build + diff + switch; asks for sudo itself at activation (never `sudo nrs`)
nrb             # nrs --dry: build + diff only, no root — safe anywhere
nrt             # nrs --test. darwin: build + run system.checks, no activation; nixos: activate without a bootloader entry
nrs --plan      # nebula: preview the switch (dry-activate + user units), change nothing
nrs --status    # no build, no root: is the machine consistent? exits 1 if not
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

The `nr*` helpers are real executables from [nrs](../modules/nrs.md) (not shell
aliases): one script, `pkgs/nrs.sh`, on both OSes
(`modules/darwin/nrs.nix` ↔ `modules/nixos/nrs.nix`), so they also work in
non-interactive shells (agent harnesses, scripts). Extra args after the mode
pass through to `nix build` (`nrs -L`, `nrb --show-trace`). They resolve the
flake dir with `readlink -f`, dodging the symlinked-checkout gotcha above.

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
- [nrs](../modules/nrs.md) adds nom's build tree, a dix diff, streamed
  activation output and a state report on every exit (nh did the first
  two until it was removed on 2026-10-24).
- Stow-tree configs apply without any rebuild at all — see the
  [stow tree pattern](../patterns/stow-tree.md).
