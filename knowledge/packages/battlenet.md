---
type: Sub-flake
title: battlenet
description: 'Sub-flake that runs Blizzard''s Battle.net in nixpkgs'' GE-Proton without Steam or umu: a `battlenet` launcher inside steam.buildRuntimeEnv that installs Battle.net into a configurable prefix on first run, plus the programs.battlenet NixOS module; enabled on nebula.'
resource: flakes/battlenet/
tags: [sub-flake, package, gaming, proton, wine]
generated: { by: claude-code/opus-5.5, at: 2026-10-25T14:00:00-07:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/battlenet/README.md
    title: 'flakes/battlenet/README.md (how it runs, first run, commands, module)'
  - id: steam-package
    resource: https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/st/steam/package.nix
    title: 'nixpkgs `steam` package (`buildRuntimeEnv`, the steam-run builder)'
  - id: umu-run-source
    resource: https://github.com/Open-Wine-Components/umu-launcher/blob/main/umu/umu_run.py
    title: 'umu-launcher `umu/umu_run.py` (the environment umu hands Proton)'
  - id: ge-proton-readme
    resource: https://github.com/GloriousEggroll/proton-ge-custom
    title: 'GE-Proton (proton-ge-custom) README'
---

Nix supplies the runtime and the user's home holds the app. The flake builds
`battlenet`: the `./battlenet.sh` launcher run inside
`steam.buildRuntimeEnv`, the bubblewrap FHS builder behind `steam-run` and
nixpkgs' `umu-launcher`.[^steam-package] That environment gives GE-Proton's
prebuilt binaries their `/lib64` loader and its `proton` script `python3`. It
uses Steam's library set, not Steam, so the package is free and builds
standalone without allowing unfree. Battle.net itself is never in the store.
On the first run the launcher downloads Blizzard's installer to
`~/.cache/battlenet/` and runs it into the prefix, and Battle.net updates
itself from then on ([decision](../decisions/battlenet-runtime-install.md)).[^subflake-readme]

Outputs, x86_64-linux only:

- `packages.battlenet` (and `default`), re-exported by the root in
  `modules/packages.nix`. `package.nix` is overridable: `proton`, `prefix`,
  `locale`, `icon`, `environment`.
- `nixosModules.battlenet` (and `default`), re-exported as the
  [battlenet module](../modules/battlenet.md): `programs.battlenet.*`.

The launcher calls `proton waitforexitandrun` directly with the variables
umu-run sets, minus the pressure-vessel container.[^umu-run-source]
`STEAM_COMPAT_DATA_PATH` is the prefix. `STEAM_COMPAT_CLIENT_INSTALL_PATH`
is empty because there is no Steam client. `UMU_ID=umu-battlenet` puts
GE-Proton in its no-Steam mode. `STORE=battlenet` makes GE-Proton turn on
write-copy emulation itself, the setting Faugus passes by hand as
`WINE_SIMULATE_WRITECOPY=1`. Commands: none (start, or install if missing),
`install`, `run CMD`, `kill` (also a desktop action).

Gotchas:

- **Unsupported upstream.** GE-Proton's README says non-Steam games outside
  Steam are only supported through umu.[^ge-proton-readme]
- **Private `/tmp`.** `buildRuntimeEnv` defaults to `privateTmp = true`, so
  a prefix under `/tmp` is invisible inside it (bwrap: "Can't chdir").
- `battlenet kill` exits 1 when nothing is running, because that's what
  `wineserver -k` returns.

Smoke test, 2026-10-25: with `BATTLENET_PREFIX` set to an empty directory,
`battlenet run cmd.exe /c ver` built a Proton-layout prefix stamped
`GE-Proton11-11`. Proton's options included `writecopy`, protonfixes reported
"Battle.net store specified", and it printed `Microsoft Windows 10.0.19045`.
The Battle.net installer itself was not run, because it opens GUI windows.

Consumed by the root flake as a relative-path input; see the
[sub-flake extraction pattern](../patterns/subflake-extraction.md). Enabled on
[nebula](../hosts/nebula.md) by
[nebula-battlenet](../modules/nebula-battlenet.md).

## Source

- Flake: [`flakes/battlenet/`](../../flakes/battlenet/)
- README: [`flakes/battlenet/README.md`](../../flakes/battlenet/README.md)

[^subflake-readme]: `flakes/battlenet/README.md`: how it runs, and first run from nothing
[^steam-package]: nixpkgs `steam` package: `buildRuntimeEnv` and `passthru.run` (steam-run)
[^umu-run-source]: umu-launcher `umu/umu_run.py`, `set_env()`
[^ge-proton-readme]: GE-Proton README: "Running non-Steam games with GE-Proton outside of Steam is only supported using umu"
