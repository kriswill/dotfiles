---
type: NixOS Module
title: Battle.net
description: 'Re-export of the battlenet sub-flake''s NixOS module: programs.battlenet installs a `battlenet` launcher and desktop entry that run Blizzard''s Battle.net in GE-Proton (no Steam, no umu), with a configurable prefix; enabled on nebula.'
resource: modules/nixos/battlenet.nix
tags: [nixos-module, gaming, proton]
generated: { by: claude-code/opus-5.5, at: 2026-10-25T14:00:00-07:00 }
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
- `prefix` (default `Games/battlenet`) is the compat data directory
  (`STEAM_COMPAT_DATA_PATH`); the Wine prefix is its `pfx/`. A relative path
  is under each user's home. An umu prefix works if you point at its `pfx`
  directory, because umu leaves a `pfx -> .` link in it.
- `proton` (default `pkgs.proton-ge-bin`): a package with a `steamcompattool`
  output, or a package holding `proton`.
- `locale` (installer `--lang`, default `enUS`), `icon`, and `environment`
  (extra Proton variables).
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
