---
type: Sub-flake
title: battlenet
description: 'Sub-flake that runs Blizzard''s Battle.net in nixpkgs'' GE-Proton without Steam or umu: a host-side `battlenet` launcher that keeps one wineserver per prefix and hands Proton to a steam.buildRuntimeEnv sandbox, installs Battle.net into a configurable prefix on first run, plus the programs.battlenet NixOS module; enabled on nebula.'
resource: flakes/battlenet/
tags: [sub-flake, package, gaming, proton, wine]
generated: { by: claude-code/opus-5.5, at: 2026-10-25T15:30:00-07:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/battlenet/README.md
    title: 'flakes/battlenet/README.md (how it runs, one wineserver, first run, commands, module)'
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

Nix supplies the runtime and the user's home holds the app. Battle.net itself
is never in the store. On the first run the launcher downloads Blizzard's
installer to `~/.cache/battlenet/` and runs it into the prefix, and Battle.net
updates itself from then on
([decision](../decisions/battlenet-runtime-install.md)).[^subflake-readme]

The launcher has two halves:

- **`battlenet` (`battlenet.sh`) runs on the host.** It resolves the prefix,
  finds the prefix's wineserver from any sandbox, then joins it, refuses, or
  starts fresh. It also does `kill`.
- **`battlenet-proton` (`battlenet-proton.sh`) runs inside
  `steam.buildRuntimeEnv`**, the bubblewrap FHS builder behind `steam-run` and
  nixpkgs' `umu-launcher`.[^steam-package] That environment gives GE-Proton's
  prebuilt binaries their `/lib64` loader and its `proton` script `python3`.
  It uses Steam's library set, not Steam, so the package is free and builds
  standalone without allowing unfree. This half sets Proton's environment
  (what umu-run sets, minus the container),[^umu-run-source] runs the
  installer under a lock, and executes the Proton verb the host chose.

The environment details:

- `UMU_ID=umu-battlenet` puts GE-Proton in its no-Steam mode.
- `STORE=battlenet` makes it turn on write-copy emulation itself.
- `PROTON_USE_XALIA=0` unless set.

Outputs (x86_64-linux only):

- `packages.battlenet` (and `default`) is a `symlinkJoin` of the host
  launcher and the desktop entry. The root re-exports it in
  `modules/packages.nix`. `package.nix` is overridable: `proton`, `prefix`,
  `locale`, `icon`, `environment`.
- `nixosModules.battlenet` (and `default`) is re-exported as the
  [battlenet module](../modules/battlenet.md): `programs.battlenet.*`.

**One prefix, one wineserver**
([decision](../decisions/battlenet-one-wineserver.md)):

- The sandbox shares the host's `/tmp`, where Wine keeps the server socket.
- A second invocation joins a running session with `runinprefix`, which
  skips prefix setup. A second Battle.net.exe hands over to the running one.
- A server in another sandbox, such as the umu entry, makes `battlenet`
  refuse.
- `install` needs the prefix idle.
- The invocation that starts the session owns it. Ctrl-C, SIGTERM or the
  terminal closing kills its child tree, then stops the prefix. Wine puts its
  programs in sessions of their own, so a terminal Ctrl-C had reached only
  Proton's Python wrapper (a `KeyboardInterrupt` traceback) while Battle.net
  ran on. Joiners don't own the session.
- `kill` stops every wineserver and every Wine process of the prefix,
  whichever launcher started them.

Gotchas:

- **Unsupported upstream.** GE-Proton's README says non-Steam games outside
  Steam are only supported through umu.[^ge-proton-readme]
- **The sandbox can't see other processes.** Inside bwrap's user namespace,
  the kernel denies reading other processes' `/proc/PID/cwd` and `environ`.
  `[ -O ]` still passes, so a scan run there silently finds nothing. That is
  why detection and `kill` live in the host half.
- **Wine programs outlive their wineserver.** Battle.net's Chromium processes
  can leave a zombie main thread, whose environment is unreadable, with
  dozens of live threads holding its windows. `kill` reads each thread's
  environment and signals the whole process.
- **Libraries the container would supply.** `buildRuntimeEnv`'s own library
  set is minimal (glibc, GL, DRM/GBM, udev, VA-API, Vulkan, NetworkManager).
  Wine's unix modules need more, and in 32 bits too, because GE-Proton 11
  still ships `i386-unix`. `extraLibraries` adds FreeType, Fontconfig, the X11
  extensions, ALSA, PulseAudio, SDL2 and libgcrypt. Without them, the 32-bit
  Battle.net installer logged "Wine cannot find the FreeType font library".
  Checking every library name in `files/lib/wine/*-unix/*.so` against the
  sandbox leaves only `libodbc` and `libpcsclite` missing. Proton's bundled
  ffmpeg (`libavutil.so.60`, both widths) links `libvdpau.so.1`. Without it
  the ffmpeg stack, and so `winedmo` (Wine's ffmpeg-based Media Foundation
  demuxer and decoder), failed to load in the 9 Battle.net processes that use
  it, with nothing in Proton's log. A loader trace found it, and
  `extraLibraries` now adds `libvdpau`. A `readelf` sweep of every bundled
  library's `NEEDED` entries against the sandbox now finds nothing missing.
- **What WoW runs on**, layer by layer (vkd3d-proton, DXVK, DXVK-NVAPI,
  winepulse, winebus with SDL3, fsync or ntsync), and which log lines are
  normal for it (an exception every 10 s from `Wow_loader.dll`, vkd3d's
  cache rebuild after a driver or Proton change), are in the README's "What
  WoW runs on".[^subflake-readme]
- **How to look:** `PROTON_LOG=1 PROTON_LOG_DIR=DIR LD_DEBUG=libs
  LD_DEBUG_OUTPUT=DIR/ld/ld battlenet`. Programs Battle.net starts, WoW
  included, inherit both. A missing library is a `find library=` block where
  every try ends "(no such file)". `version lookup error` lines are version
  mismatches. "symbol lookup error" lines are mostly optional probes (NVIDIA
  app profiles, libudev's syscall wrappers, Wine's own). The one Wine tolerates
  is the `gnutls_ecdh_compute_key` that modern gnutls no longer exports.
  `libd3d12.so` is Mesa's WSL-only Dozen driver probing.
- **Proton's bundled libraries can shadow nixpkgs'.** Proton puts
  `files/lib/*-linux-gnu` first on `LD_LIBRARY_PATH`. Its libxkbcommon
  (newest version tag `V_1.9.0`) shadowed nixpkgs' 1.13.2. nixpkgs' SDL3
  needs `V_1.10.0`, so in the 64-bit `winedevice.exe` sdl2-compat printed
  "Failed loading SDL3 library." and `winebus.sys` lost its SDL controller
  backend. A loader trace (`LD_DEBUG=libs`) found the "version lookup error".
  A `steam-run` test without Proton's `LD_LIBRARY_PATH` had wrongly suggested
  SDL3 loaded fine. `package.nix` now builds `protonDir`, the Proton tree
  without the bundled libxkbcommon and libxkbregistry, with real directories
  only down to those lib dirs (Proton copies `default_pfx` symlinks into new
  prefixes as they are). Proton keys a prefix's built-in DLL links on its
  library paths in `config_info`, so a changed path relinks on the next
  start. After the change, the live `winedevice.exe` mapped SDL3 and nixpkgs'
  libxkbcommon. GE-Proton also bundles ffmpeg's libav*, libxml2, liblzma and
  libsoup, but nothing else was seen failing.

## Source

- Flake: [`flakes/battlenet/`](../../flakes/battlenet/)
- README: [`flakes/battlenet/README.md`](../../flakes/battlenet/README.md)

Consumed by the root flake as a relative-path input; see the
[sub-flake extraction pattern](../patterns/subflake-extraction.md). Enabled on
[nebula](../hosts/nebula.md) by
[nebula-battlenet](../modules/nebula-battlenet.md).

[^subflake-readme]: `flakes/battlenet/README.md`: how it runs, one wineserver, first run from nothing
[^steam-package]: nixpkgs `steam` package: `buildRuntimeEnv` and `passthru.run` (steam-run)
[^umu-run-source]: umu-launcher `umu/umu_run.py`, `set_env()`
[^ge-proton-readme]: GE-Proton README: "Running non-Steam games with GE-Proton outside of Steam is only supported using umu"
