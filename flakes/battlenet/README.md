# battlenet

Runs Blizzard's [Battle.net](https://download.battle.net/) launcher on NixOS
in GE-Proton, without Steam and without umu. It provides a `battlenet` command,
a "Battle.net" desktop entry, and a NixOS module (`programs.battlenet`).

Battle.net itself is not packaged. It is closed-source and updates itself, so
Nix supplies only what runs it: Proton, a filesystem layout Proton's binaries
can run in, and the launcher. Battle.net and its games live in a prefix in the
user's home.

## How it runs

```
battlenet (host: finds the prefix's wineserver, joins or refuses, kills)
 └ bwrap FHS env (steam.buildRuntimeEnv)
    └ battlenet-proton (Proton's environment, installer)
       └ <proton>/proton waitforexitandrun | runinprefix Battle.net.exe
          └ Wine prefix: $prefix/pfx
```

- **The FHS environment.** GE-Proton ships prebuilt binaries linked against
  `/lib64/ld-linux-x86-64.so.2`, and its `proton` script starts with
  `#!/usr/bin/env python3`. NixOS has neither, so `battlenet-proton` runs
  inside `steam.buildRuntimeEnv`, the bubblewrap environment nixpkgs builds for
  Steam (the same builder as `steam-run` and nixpkgs' `umu-launcher`). It is
  free software: it brings Steam's libraries, not Steam.
- **No Steam Runtime container.** umu would also start Valve's pressure-vessel
  container inside that. This launcher calls Proton directly, so host
  libraries come from nixpkgs. Steam's FHS library set expects that container
  to supply most of them, so the package adds what Wine's unix modules load,
  in 32 and 64 bits: FreeType, Fontconfig, the X11 extensions, ALSA,
  PulseAudio, SDL2 and libgcrypt. GE-Proton 11 still runs 32-bit programs on
  32-bit unix modules, and Blizzard's installer is one of them, so without
  32-bit FreeType it can't draw text. It also adds `libvdpau`, which
  Proton's bundled ffmpeg (`libavutil`) links. Without it the whole ffmpeg
  stack failed to load, and with it `winedmo`, Wine's ffmpeg-based Media
  Foundation demuxer and decoder. That failure was silent in Proton's log and
  only showed in a loader trace. Every dependency of Proton's bundled
  libraries now resolves. Of the libraries Wine's unix modules load, only
  `libodbc` and `libpcsclite` (databases, smart cards) remain absent.
- **Proton's bundled libxkbcommon is left out.** GE-Proton bundles an old
  libxkbcommon (newest version tag `V_1.9.0`) and puts its own lib
  directories first on `LD_LIBRARY_PATH`. Inside Valve's runtime that copy
  matches everything else. Here it shadowed nixpkgs' copy, and nixpkgs' SDL3
  needs `V_1.10.0`, so SDL3 failed to load. sdl2-compat printed "Failed
  loading SDL3 library.", and Wine's controller driver (`winebus.sys`) ran
  without SDL, its main game-controller backend. The package now runs a copy
  of the Proton tree without the bundled libxkbcommon and libxkbregistry, so
  nixpkgs' copies load. They keep every older version tag. Only the
  directories down to `files/lib/*-linux-gnu` are real; everything else
  links to the original. That matters because Proton copies the symlinks in
  `files/share/default_pfx` into new prefixes as they are. Proton records its
  library paths in the prefix's `config_info` and relinks the prefix's
  built-in DLLs when they change, so a new Proton path is picked up on the
  next start.
- **The environment** is what umu-run hands Proton.
  `STEAM_COMPAT_CLIENT_INSTALL_PATH` is set but empty, since there is no Steam
  client. GE-Proton reads `UMU_ID` as running without Steam (it turns
  `lsteamclient` off) and `STORE=battlenet` as a request for write-copy
  emulation (`WINE_SIMULATE_WRITECOPY`), which Battle.net needs. Xalia,
  Proton's gamepad navigation for launcher windows, is off unless
  `PROTON_USE_XALIA=1`: Battle.net is driven by mouse, and Xalia floods
  stderr with `TaskCanceledException` traces.

GE-Proton's README says running non-Steam games outside Steam is only
supported through umu. This route works, but upstream won't help with it.

## One prefix, one wineserver

Wine runs one wineserver per prefix and finds it through a socket in
`/tmp/.wine-$UID/server-<dev>-<inode>`, named after the prefix directory. Two
wineservers on one prefix overwrite each other's registry, and each starts its
own Battle.net. So:

- **The sandbox shares the host's `/tmp`** (`privateTmp = false`, as nixpkgs'
  Heroic does). With a private `/tmp` per invocation, every `battlenet` started
  its own wineserver on the prefix, and `battlenet kill` couldn't see the
  running one.
- **`battlenet` looks for the prefix's wineserver before starting anything.**
  A wineserver's working directory is its socket directory, so `/proc` finds
  it whatever sandbox it runs in. If its `/tmp` is ours, the new invocation
  joins it with Proton's `runinprefix` verb, which skips prefix setup; a
  second Battle.net.exe in the same wineserver hands over to the running one.
  If it isn't (another sandbox, such as an umu launcher on the same prefix),
  `battlenet` refuses instead of starting a second server.
- **This half runs on the host.** Inside bwrap's user namespace the kernel
  hides other processes' `cwd` and `environ`, so the check can't run in the
  sandbox.
- **Installs take a lock**, because a second click can arrive while the first
  install is still building the prefix, before its wineserver exists.
- **The invocation that starts the session owns it.** It waits in the
  foreground, and Ctrl-C, SIGTERM or the terminal closing stops everything in
  the prefix. Wine puts its programs in sessions of their own, so the
  terminal's interrupt alone reached only Proton's Python wrapper, which died
  with a traceback while Battle.net kept running. The launcher now runs
  Proton as a background job, which ignores SIGINT, and traps the signal. It
  kills its own child tree first, so Proton can't start more Wine when the
  signal lands mid-setup, then stops the prefix. Invocations that join a
  running session don't own it, so interrupting `battlenet run winecfg`
  leaves Battle.net alone.
- **`battlenet kill` works from any launcher.** It sends the prefix's
  wineservers SIGTERM, which makes them save the registry and exit, then
  kills every process whose `WINEPREFIX` is the prefix. Programs don't exit
  with their wineserver, and Battle.net's Chromium processes can leave a
  zombie main thread with live threads that keep its windows open, so the
  scan reads each thread's environment and signals the whole process.

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

## What WoW runs on

From a logged session on 2026-10-25 (GE-Proton11-11, `PROTON_LOG=1` and
`LD_DEBUG=libs`, WoW started from Battle.net):

| Layer | Windows side | Linux side |
| --- | --- | --- |
| Game | `Wow.exe` (64-bit), via Blizzard's `Wow_loader.dll` | |
| Direct3D 12 | `d3d12.dll` + `d3d12core.dll` (vkd3d-proton) | `winevulkan` → `libvulkan.so.1` → the GPU's Vulkan driver; uses `VK_EXT_descriptor_buffer` |
| DXGI / Direct3D 11 | `dxgi.dll` + `d3d11.dll` (DXVK 3.1.1); Battle.net's Chromium windows draw through it too | same Vulkan path |
| NVIDIA API | `nvapi64.dll` (DXVK-NVAPI 0.9.2) answers WoW's GPU, architecture and driver queries | Proton's `nvml` bridge → `libnvidia-ml.so.1` |
| Audio | `mmdevapi.dll` + `winepulse.drv` | `libpulse.so.0` (PipeWire's PulseAudio server) |
| Controllers | `xinput1_4.dll` + `hid.dll` → `winebus.sys` in `winedevice.exe` | sdl2-compat → SDL3 |
| Network, login | `bcrypt.dll`, `winhttp.dll` | gnutls, Kerberos |
| Synchronisation | | fsync; ntsync when `/dev/ntsync` exists (`PROTON_NO_NTSYNC=1` opts out) |
| Display | `winex11.drv` (XWayland) by default; `winewayland.drv` with `PROTON_ENABLE_WAYLAND=1` | X server or Wayland compositor |

The loader trace had no version errors and no missing libraries in WoW. These
are normal in its logs:

- **An exception every 10 seconds:** a breakpoint (`0x80000003`) and then an
  assertion failure (`0xc0000420`) raised in `Wow_loader.dll`, logged as
  `err:seh:dispatch_exception assertion failure exception`. WoW handles each
  one and keeps running. The precise period suggests a deliberate check in
  the game's code, not a fault.
- **`Cannot load existing on-disk cache due to driver version mismatch`**
  from vkd3d-proton. Its pipeline cache is `_retail_/vkd3d-proton.cache`, and
  a cache from another driver or vkd3d build is rebuilt once. Expect some
  stutter in the first session after a driver or Proton change.
- **vkd3d-proton warnings:** no OpenXR/OpenVR runtime, missing WMMA
  (cooperative matrix), `shader_float_controls2` disabled on NVIDIA as a
  deliberate workaround, and no separate queue for out-of-band work.
- **`fixme:pulse … Unhandled channel auxN`:** the output device advertises
  auxiliary channels that Wine ignores.
- **Every Mesa Vulkan driver loads in WoW too** (Intel, Radeon, Nouveau and so
  on), because the Vulkan loader enumerates all installed drivers.
- **Loader "symbol lookup errors"** are optional probes: NVIDIA's app-profile
  detection, libudev's syscall wrappers, Wine's own.
- **`libd3d12.so` not found:** Mesa's WSL-only Dozen driver.

Collect the same logs with

```sh
PROTON_LOG=1 PROTON_LOG_DIR=$HOME/.cache/battlenet-logs \
  LD_DEBUG=libs LD_DEBUG_OUTPUT=$HOME/.cache/battlenet-logs/ld/ld battlenet
```

Create `ld/` first. Programs Battle.net starts, WoW included, inherit both
settings. `steam-battlenet.log` is Proton's log, and the loader writes one
`ld.PID` file per process. A missing library is a `find library=` block where
every try ends "(no such file)". A version mismatch is a `version lookup
error` line. Turn both off for normal play: Proton then traces every one of
WoW's periodic exceptions.

## Commands

| Command | Does |
| --- | --- |
| `battlenet` | Starts Battle.net; installs it first if `Battle.net.exe` is missing. If it's already running, brings it forward. Ctrl-C stops it. |
| `battlenet install` | Downloads the installer again and runs it (repair or reinstall). Refused while anything runs in the prefix. |
| `battlenet run CMD [ARG...]` | Runs a program in the prefix: `winecfg`, `regedit`, any `.exe`. Joins a running session. |
| `battlenet kill` | Stops everything in the prefix, whichever launcher started it. Also a desktop action. |

`BATTLENET_PREFIX=/path battlenet ...` uses another prefix for one run.
`BATTLENET_CPUS=LIST` overrides the CPU list for one run, and an empty value
turns pinning off. `BATTLENET_CONFINE="SLICE ..."` overrides what is held
off those CPUs (space-separated user slices, plus `nix-daemon.service`), and
an empty value turns confinement off.

## CPU pinning

`programs.battlenet.cpus` takes a `taskset -c` list, for example
`"0-5,12-17"`. The launcher starts the sandbox under `taskset`, so the
sandbox, Proton, the wineserver and every Windows program Battle.net starts
inherit the affinity. Programs added with `battlenet run` while a session
runs are pinned the same way. It also derives `WINE_CPU_TOPOLOGY`
(`count:cpu,cpu,…`) from the kernel's normalised form of the list, so Wine
reports only those CPUs to Windows programs. Set `WINE_CPU_TOPOLOGY` yourself
to override it, or to an empty value to turn it off.

Both are needed. Affinity is only a starting point, since a process may widen
its own. Before the topology was set, WoW set its process affinity to "all
processors", which Wine had reported as all 24 CPUs. 76 of its 99 threads
then ran on all 24: its job pools (`ThreadPool High/Mid/Low`), 22 QUIC
`cxplat_worker` threads, vkd3d's queue threads, and Wine's audio and input
threads. So did the `WowVoiceProxy.exe` it started. Only threads created
before that call stayed pinned. With the topology set, "all processors" means
the pinned CPUs. Wine reports them as separate cores without SMT pairing (WMI:
12 cores, 12 logical processors), and games size their thread pools to the
CPUs they actually get.

On AMD X3D CPUs, pin the session to the 3D V-Cache CCD: the CPUs whose
`/sys/devices/system/cpu/cpuN/cache/index3/shared_cpu_list` share the large
L3. Leaving the kernel's `amd_x3d_vcache` mode at `frequency` then steers
other work to the other CCD.

### Keeping other work off those CPUs

Pinning keeps the game on its CPUs, not other work off them, and the X3D
mode is only a preference. Affinity can't help either: it can't reach
programs started outside the launcher, such as a compiler cache's server,
which spawns the compilers of every build. A cgroup cpuset can, because the
kernel enforces it on every process in the cgroup. While a session runs,
`programs.battlenet.confineSlices` holds user slices to the CPUs outside
`cpus`, and `confineNixDaemon` does the same for `nix-daemon.service`, where
Nix builds run. With `cpus = "0-5,12-17"` on a 24-CPU machine, each gets
`6-11,18-23`.

- **The game runs in its own scope.** Every invocation that starts Wine runs
  the sandbox with `systemd-run --user --scope --slice=battlenet.slice`, so
  the game is never in a confined slice, even when started from a terminal
  in `app.slice`. There, `taskset` to the session's CPUs would fail with
  EINVAL, because a cpuset bounds affinity. In scope mode `systemd-run`
  registers its own PID as the scope and then execs the command, so the PID
  the launcher waits on and kills is the sandbox's, as before. It runs with
  `--expand-environment=no`, since `systemd-run` otherwise expands `$` in
  `battlenet run` arguments. The CPU list is checked in such a scope too.
- **systemd tracks how long it lasts.** The scope wants
  `battlenet-confine@TARGET:CPUS.service` for each target, for example
  `battlenet-confine@app.slice:0-5_12-17.service` (commas become
  underscores, since unit names can't hold them). That unit is
  `StopWhenUnneeded=`, so systemd starts it with the first scope that wants
  it and stops it once the last such scope has ended. The confinement
  therefore ends with Wine, not with the launcher: a launcher killed with
  SIGKILL leaves it in place until the game exits, and `battlenet kill` has
  nothing to clear. Sessions with the same CPUs share one unit. Its start
  and its stop both run `battlenet _confine`, which, under a lock, sets the
  target to the online CPUs outside every session still running on it, and
  clears `AllowedCPUs` after the last. The launcher owns that property on
  its targets, so it clears it rather than restoring an earlier value. If
  the sessions have every online CPU, nothing is confined.
- **A user slice needs the `cpuset` controller delegated to the user's
  systemd.** `user@.service` delegates only `pids memory cpu`, so a user
  slice's `AllowedCPUs` did nothing. A non-empty `confineSlices` sets
  `Delegate=pids memory cpu cpuset`. A switch doesn't restart
  `user@.service`, but it re-executes running user managers, which hands
  them the controller. Without it, the slice has no cpuset files, and the
  confinement says so in a notification and the journal. It also says so when
  a target's `cpuset.cpus.effective` isn't the list it set.
- **`nix-daemon.service` belongs to the system manager**, which a user's
  launcher can't change. `confineNixDaemon` installs a polkit rule that
  lets members of `users` start `battlenet-confine-nix@CPUS.service`, a
  root oneshot that sets `nix-daemon.service`'s `AllowedCPUs` to `CPUS`
  (`none` clears it). The instance comes from a user, so its script accepts
  only a CPU list. Builds that are already running move too.
- **When `systemd-run` can't start a scope**, the launcher says so and runs
  as it did before: no scope, no confinement. From a confined terminal
  (with no scope to escape to), it says the shell is held to other CPUs
  instead of calling the list invalid.

Leave the compositor's slice (`session.slice`) out unless you mean to: it
holds the compositor and what it starts directly, which is light work, and
the game waits on the compositor's frames. `battlenet.slice` and the root
slice (`-.slice`), which hold the session, can't be confined; the module
refuses them, and the launcher skips them.

Runtime properties outlive their unit. If the user manager dies while a
session runs, a slice can stay confined. The next session's end clears it,
or clear it by hand with `systemctl --user set-property --runtime app.slice
AllowedCPUs=` (and `systemctl start battlenet-confine-nix@none.service` for
`nix-daemon.service`).

## The NixOS module

```nix
{ inputs, ... }:
{
  imports = [ inputs.battlenet.nixosModules.default ];

  programs.battlenet = {
    enable = true;
    # prefix = "Games/battlenet";          # default null: ~/.local/share/battlenet; relative = under $HOME
    # proton = pkgs.proton-ge-bin;          # default
    # cpus = "0-5,12-17";                   # pin the session (taskset -c list)
    # confineSlices = [ "app.slice" ];      # hold these user slices off `cpus` while it runs
    # confineNixDaemon = true;              # and Nix builds (adds a polkit rule)
    # locale = "enUS";                      # installer language
    # icon = "/path/to/icon.png";           # default: applications-games
    # environment.PROTON_ENABLE_WAYLAND = "1";
  };
}
```

`prefix` is the compat data directory (`STEAM_COMPAT_DATA_PATH`); the Wine
prefix is its `pfx/`. By default it's `$XDG_DATA_HOME/battlenet`
(`~/.local/share/battlenet`), resolved per user at run time, and outside
anything Steam manages. To reuse an umu prefix, point at its `pfx` directory:
umu uses the prefix as its own compat data directory and leaves a `pfx -> .`
link in it, so `$prefix/pfx` still resolves. Don't run the umu launcher and
this one on the prefix at the same time: `battlenet` refuses while umu's
wineserver is up. `programs.battlenet.package` is the launcher built from
these options (read-only).

## Native Wayland

GE-Proton uses Wine's X11 driver, so Battle.net and WoW run under XWayland,
unless `PROTON_ENABLE_WAYLAND=1`. With it, Proton selects Wine's Wayland
driver and EGL for OpenGL, turns off its fullscreen hack, and forces Xalia
off: Wayland lets no client position its own windows. Set it through
`programs.battlenet.environment`. Those values are defaults, so
`PROTON_ENABLE_WAYLAND=0 battlenet` tries XWayland again for one run. What
to expect:

- **Set `PROTON_WAYLAND_MONITOR` to the game's monitor.** Proton tells Wine
  which monitor is primary by looking for xrandr's `primary` output. XWayland
  under wlroots compositors such as Hyprland marks none, so Wine picks one
  itself, and WoW may size itself for the wrong screen.
- **Window classes change** to the executable names (`battle.net.exe`,
  `wow.exe`). Under XWayland both share one `steam_app_…` class, so
  compositor rules that match on title keep working.
- **WoW's exclusive fullscreen** (`gxWindow "0"`) asks the compositor to
  leave fullscreen while its window isn't monitor-sized. A compositor rule
  that forces fullscreen has to ignore WoW's own fullscreen requests too (in
  Hyprland, `suppress_event = "fullscreen"`).
- **Battle.net's window** lays out oddly for a few seconds after it opens,
  then settles.
- **Mesa EGL warnings** (`pci id for fd N: 10de:…, driver (null)`, `failed to
  create dri2 screen`) on NVIDIA are harmless. Wine's desktop process loads
  both Mesa's and NVIDIA's EGL through glvnd, Mesa finds no driver for the GPU,
  and NVIDIA's EGL takes over. The games render through Vulkan anyway.

## Moving a prefix out of Steam

A prefix Steam or umu created can move to the default location, so Steam
can't remove or reset it. Battle.net's and WoW's settings use `C:\` paths, so
nothing inside needs rewriting. Two things do need fixing:

- **Layout.** umu uses the Wine prefix as its own compat data directory and
  leaves a `pfx -> .` link in it. Move that directory to
  `~/.local/share/battlenet/pfx` and delete the `pfx` link. Move Proton's
  `version`, `config_info`, `tracked_files`, `shadercache` and
  `gstreamer-1.0` up next to `pfx/`, and delete `pfx.lock`.
- **Links into Steam's Proton.** A prefix Valve's Proton set up can still
  contain links into `steamapps/common/Proton …` that GE-Proton's relink
  never replaces. Proton relinks only what's in its `default_pfx`, and these
  aren't: the .NET placeholders wine-mono added under `Microsoft.NET/`, and
  `winegstreamer.dll`, which GE-Proton doesn't ship. Replace each placeholder
  with a copy of GE-Proton's same-named file. Wine loads its own built-in
  for such placeholders, so a copy survives GE-Proton updates. Delete the
  `winegstreamer.dll` links.

  `find ~/.local/share/battlenet -type l -lname '*steamapps*'` should then
  find nothing.

Stop everything in the prefix first. Within one filesystem the move is a
rename, however large the WoW install.

## Files

| File | Purpose |
| --- | --- |
| [`flake.nix`](flake.nix) | flake-parts flake: `packages.x86_64-linux.battlenet` (+ `default`) and `nixosModules.battlenet` (+ `default`). |
| [`package.nix`](package.nix) | The FHS environment, both halves of the launcher, the desktop entry, and the confinement units (`battlenet-confine@.service` for the user, `battlenet-confine-nix@.service` for the system). Overridable: `proton`, `prefix`, `cpus`, `confineSlices`, `confineNixDaemon`, `locale`, `icon`, `environment`. |
| [`battlenet.sh`](battlenet.sh) | The host half: prefix, wineserver detection, join or refuse, `kill`, CPU pinning, and `_confine`, which the confinement unit runs. |
| [`battlenet-proton.sh`](battlenet-proton.sh) | The sandbox half: Proton's environment, installer download and lock, the Proton verb. |
| [`nixos-module.nix`](nixos-module.nix) | `programs.battlenet.*`, the units (`systemd.packages`), the `cpuset` delegation and the polkit rule. |

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
