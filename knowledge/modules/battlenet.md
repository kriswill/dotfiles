---
type: NixOS Module
title: Battle.net
description: 'Re-export of the battlenet sub-flake''s NixOS module: programs.battlenet installs a `battlenet` launcher and desktop entry that run Blizzard''s Battle.net in GE-Proton (no Steam, no umu), with a configurable prefix; enabled on nebula.'
resource: modules/nixos/battlenet.nix
tags: [nixos-module, gaming, proton]
generated: { by: claude-code/opus-5.5, at: 2026-10-27T23:30:00-07:00 }
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
  `environment.systemPackages`, and the package to `systemd.packages` for its
  confinement units. The launcher is built with `config.systemd.package`, so
  its `systemctl` and `systemd-run` match the running manager.
- `prefix` is the compat data directory (`STEAM_COMPAT_DATA_PATH`); the Wine
  prefix is its `pfx/`. The default is `null`, meaning
  `$XDG_DATA_HOME/battlenet` (`~/.local/share/battlenet`), resolved per user
  at run time and outside anything Steam manages. It was `Games/battlenet`
  until 2026-10-25. A relative path is under each user's home. An umu prefix works if you point at its `pfx`
  directory, because umu leaves a `pfx -> .` link in it.
- `proton` (default `pkgs.proton-ge-bin`): a package with a `steamcompattool`
  output, or a package holding `proton`.
- `cpus` (default `null`, otherwise non-empty): a `taskset -c` list the whole session runs on
  (Battle.net, WoW, Proton, the wineserver inherit it); `BATTLENET_CPUS`
  overrides it per run. The launcher also derives `WINE_CPU_TOPOLOGY` from
  it, so Wine reports only those CPUs. Without that, WoW's "all processors"
  affinity spread 76 of its 99 threads back over every CPU.
- `confineSlices` (default `[]`, names matching `*.slice`): user slices held
  to the CPUs outside `cpus` (a cgroup cpuset, `AllowedCPUs`) while a session
  runs, so the work in them stays off the game's CPUs. A non-empty list
  asserts `cpus` is set and that `battlenet.slice` and `-.slice` (which hold
  the session) aren't listed, and adds `cpuset` to `user@.service`'s
  `Delegate=`. The switch's re-execution of running user managers hands it
  over ([decision](../decisions/battlenet-cpu-confinement.md)).
  `BATTLENET_CONFINE` overrides the list per run.
- `confineNixDaemon` (default `false`): hold `nix-daemon.service`, where Nix
  builds run, there too. Adds a polkit rule that lets members of `users`
  start the root oneshot `battlenet-confine-nix@CPUS.service`, and asserts
  `cpus` and `security.polkit.enable`.
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
