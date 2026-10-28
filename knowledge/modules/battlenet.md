---
type: NixOS Module
title: Battle.net
description: 'Re-export of the battlenet sub-flake''s NixOS module: programs.battlenet installs a `battlenet` launcher and desktop entry that run Blizzard''s Battle.net in GE-Proton (no Steam, no umu), with a configurable prefix; enabled on nebula.'
resource: modules/nixos/battlenet.nix
tags: [nixos-module, gaming, proton]
generated: { by: claude-code/opus-5.5, at: 2026-10-26T22:45:00-07:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/battlenet/README.md
    title: 'flakes/battlenet/README.md (the NixOS module)'
---

A one-line re-export of `inputs.battlenet.nixosModules.battlenet`, from the
[battlenet sub-flake](../packages/battlenet.md). The module builds the
launcher with `pkgs.callPackage` against the host's own pkgs, so no overlay is
needed.[^subflake-readme]

Options under `programs.battlenet`:

- `enable` adds the launcher (`bin/battlenet`, `battlenet.desktop`) to
  `environment.systemPackages`.
- `prefix` is the compat data directory (`STEAM_COMPAT_DATA_PATH`); the Wine
  prefix is its `pfx/`. The default is `null`, meaning
  `$XDG_DATA_HOME/battlenet` (`~/.local/share/battlenet`), resolved per user
  at run time and outside anything Steam manages. It was `Games/battlenet`
  until 2026-10-25. A relative path is under each user's home. An umu prefix works if you point at its `pfx`
  directory, because umu leaves a `pfx -> .` link in it.
- `proton` (default `pkgs.proton-ge-bin`): a package with a `steamcompattool`
  output, or a package holding `proton`.
- `cpus` (default `null`): a `taskset -c` list the whole session runs on
  (Battle.net, WoW, Proton, the wineserver inherit it); `BATTLENET_CPUS`
  overrides it per run. The launcher also derives `WINE_CPU_TOPOLOGY` from
  it, so Wine reports only those CPUs. Without that, WoW's "all processors"
  affinity spread 76 of its 99 threads back over every CPU.
- `confineSlices` (default `[]`): user slices held to the CPUs outside `cpus`
  while a session runs, so builds and other work stay off the game's CPUs.
  The launcher that owns the session sets each slice's `AllowedCPUs` (a
  cgroup cpuset) and clears it when it exits; `battlenet kill` clears it
  too. Every invocation that starts Wine runs in a transient scope in
  `battlenet.slice`, so the game is never confined. `BATTLENET_CONFINE`
  overrides the list per run. A non-empty list asserts `cpus` is set and
  `battlenet.slice` isn't listed, and adds `cpuset` to `user@.service`'s
  `Delegate=`, which can take until the next login to reach the user
  manager ([decision](../decisions/battlenet-cpu-confinement.md)).
- `locale` (installer `--lang`, default `enUS`), `icon`, and `environment`
  (extra Proton variables, as defaults that a variable set for one run
  overrides).
- `package` (read-only) is the launcher built from these options.

Imported on every NixOS host but disabled by default; hosts opt in with
`programs.battlenet.enable = true;`
([host-mounted modules pattern](../patterns/host-mounted-modules.md)).
Auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).
On [nebula](../hosts/nebula.md): [nebula-battlenet](nebula-battlenet.md).

## Source

- Module: [`modules/nixos/battlenet.nix`](../../modules/nixos/battlenet.nix)
- Options under: `programs.battlenet`

[^subflake-readme]: `flakes/battlenet/README.md`: the NixOS module section
