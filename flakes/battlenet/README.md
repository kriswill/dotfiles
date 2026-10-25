# battlenet

Runs Blizzard's [Battle.net](https://download.battle.net/) launcher on NixOS
in GE-Proton, without Steam and without umu. It provides a `battlenet` command,
a "Battle.net" desktop entry, and a NixOS module (`programs.battlenet`).

Battle.net itself is not packaged. It is closed-source and updates itself, so
Nix supplies only what runs it: Proton, a filesystem layout Proton's binaries
can run in, and the launcher script. Battle.net and its games live in a
prefix in the user's home.

## How it runs

```
battlenet ─ bwrap FHS env (steam.buildRuntimeEnv)
             └ battlenet-launcher (./battlenet.sh)
                └ <proton>/proton waitforexitandrun Battle.net.exe
                   └ Wine prefix: $prefix/pfx
```

- **The FHS environment.** GE-Proton ships prebuilt binaries linked against
  `/lib64/ld-linux-x86-64.so.2`, and its `proton` script starts with
  `#!/usr/bin/env python3`. NixOS has neither, so the launcher runs inside
  `steam.buildRuntimeEnv`, the bubblewrap environment nixpkgs builds for Steam
  (the same builder as `steam-run` and nixpkgs' `umu-launcher`). It is free
  software: it brings Steam's libraries, not Steam.
- **No Steam Runtime container.** umu would also start Valve's pressure-vessel
  container inside that. This launcher calls Proton directly, so host
  libraries come from nixpkgs.
- **The environment** is what umu-run hands Proton.
  `STEAM_COMPAT_CLIENT_INSTALL_PATH` is set but empty, since there is no Steam
  client. GE-Proton reads `UMU_ID` as running without Steam (it turns
  `lsteamclient` off) and `STORE=battlenet` as a request for write-copy
  emulation (`WINE_SIMULATE_WRITECOPY`), which Battle.net needs.

GE-Proton's README says running non-Steam games outside Steam is only
supported through umu. This route works, but upstream won't help with it.

## First run, from nothing

1. The prefix directory doesn't exist. `battlenet` creates it, and Proton turns
   it into a compat data directory: `pfx/` (the Wine prefix, copied from
   Proton's template), `version`, `config_info` and `tracked_files`.
2. The launcher downloads Blizzard's installer to
   `~/.cache/battlenet/Battle.net-Setup.exe` from
   `https://downloader.battle.net/download/getInstaller?os=win&installer=Battle.net-Setup.exe`,
   which redirects to the current versioned build.
3. It runs the installer with `--lang=<locale>` and
   `--installpath='C:\Program Files (x86)\Battle.net'`. The installer downloads
   the Battle.net app, installs it, and starts it.
4. You log in and install games from Battle.net. They go under `drive_c` in the
   prefix unless you pick another folder there.

Later runs start `Battle.net.exe` directly. When nixpkgs updates GE-Proton, the
prefix's `version` changes and Proton upgrades the prefix in place on the next
start.

The installer is downloaded at run time instead of being fetched by Nix. The
URL always serves the newest build, so a pinned hash would go stale, and the
installer only bootstraps a program that replaces itself anyway.

## Commands

| Command | Does |
| --- | --- |
| `battlenet` | Starts Battle.net; installs it first if `Battle.net.exe` is missing. |
| `battlenet install` | Downloads the installer again and runs it (repair or reinstall). |
| `battlenet run CMD [ARG...]` | Runs a program in the prefix: `winecfg`, `regedit`, any `.exe`. |
| `battlenet kill` | Stops everything in the prefix (`wineserver -k`). Also a desktop action. |

`BATTLENET_PREFIX=/path battlenet ...` uses another prefix for one run.

## The NixOS module

```nix
{ inputs, ... }:
{
  imports = [ inputs.battlenet.nixosModules.default ];

  programs.battlenet = {
    enable = true;
    # prefix = "Games/battlenet";          # default; relative = under $HOME
    # proton = pkgs.proton-ge-bin;          # default
    # locale = "enUS";                      # installer language
    # icon = "/path/to/icon.png";           # default: applications-games
    # environment.PROTON_ENABLE_WAYLAND = "1";
  };
}
```

`prefix` is the compat data directory (`STEAM_COMPAT_DATA_PATH`); the Wine
prefix is its `pfx/`. To reuse an umu prefix, point at its `pfx` directory:
umu uses the prefix as its own compat data directory and leaves a `pfx -> .`
link in it, so `$prefix/pfx` still resolves. `programs.battlenet.package` is
the launcher built from these options (read-only).

## Files

| File | Purpose |
| --- | --- |
| [`flake.nix`](flake.nix) | flake-parts flake: `packages.x86_64-linux.battlenet` (+ `default`) and `nixosModules.battlenet` (+ `default`). |
| [`package.nix`](package.nix) | The FHS environment, the launcher and the desktop entry. Overridable: `proton`, `prefix`, `locale`, `icon`, `environment`. |
| [`battlenet.sh`](battlenet.sh) | The launcher: prefix, installer download, Proton environment, commands. |
| [`nixos-module.nix`](nixos-module.nix) | `programs.battlenet.*`. |

## Consuming it

As a relative-path input, following the parent's nixpkgs:

```nix
battlenet = {
  url = "./flakes/battlenet";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-parts.follows = "flake-parts";
};
```

Moving it to its own repository changes only that URL.
