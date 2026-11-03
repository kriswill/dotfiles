# herdr

Everything herdr in one flake: our fork of the herdr TUI, Herdr's desktop app
and herdr-core (`hc`), the helper tools around them, an update check, and the
NixOS and nix-darwin modules that configure them. The root flake consumes it
as `inputs.herdr` (`./flakes/herdr`).

| Output | Systems | What |
|---|---|---|
| `packages.herdr-cli` (`default`) | all | the herdr TUI, from our fork (the `herdr-cli` input), with a build identity |
| `packages.herdr-nav` | all | vim-aware ctrl+h/j/k/l pane navigation for herdr |
| `packages.herdr-core` | all | `hc` / `herdr-core`: upstream's release build, untouched |
| `packages.herdr-app-unwrapped` | all | Herdr (GPUI + wgpu): upstream's release build, patchelf'd on Linux, the signed `Herdr.app` untouched on macOS |
| `packages.herdr-app` | all | the app with telemetry off and this core at the end of PATH, for `nix run` (a shell launch; Finder bypasses it) |
| `packages.herdr-update-check` | all | is any of these behind upstream, or running a stale build? |
| `nixosModules.herdr` (`default`) | | `programs.herdr-{cli,core,app}`, `services.herdr-update-check` |
| `darwinModules.herdr` (`default`) | | the same options, with the app's choices written to settings.json |

Systems: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`.

## The herdr TUI (`herdr-cli`)

Built by our fork's own flake: `github:kriswill/herdr/vX.Y.Z-custom`, the
`custom` branch rebased onto each upstream release (its patch commits are
listed on the input in `flake.nix`). `pkgs/herdr-cli.nix` stamps it with
`HERDR_BUILD_CHANNEL=kriswill-custom` and `HERDR_BUILD_ID=<fork shortRev>`, so
`herdr --version` says which fork commit it is. It builds from source; there's
no binary cache. The fork's `rust-overlay` is overridden past the tag's pin
(and follows our nixpkgs).

To move to a new upstream release, rebase `custom` onto it, tag
`vA.B.C-custom`, and repoint `herdr-cli.url`. `herdr-update-check` reminds you.

`herdr-nav` runs herdr by store path, because the herdr server spawns
`[[keys.command]]` entries with a PATH we don't control. The module installs
it by default.

## herdr-core and Herdr: repackaged release builds

Nothing compiles, so there is nothing to cache. A build fetches upstream's
tarball (the same bytes a substituter would send) and, for the Linux app,
runs patchelf, all in seconds. On macOS both are upstream's Developer
ID-signed builds, installed with no fixup at all (see "darwin"). Upstream releases about daily, and `update.ts`
picks a release up as soon as you run it. The alternatives build from source
(Rust + Zig 0.16 + vendored Ghostty):

- nixpkgs: `herdr-core` + `herdr-desktop`, NixOS/nixpkgs#581031 (open, awaiting
  review as of 2026-11-01); Hydra-cached once merged, lagging days to weeks.
- numtide's [llm-agents.nix](https://github.com/numtide/llm-agents.nix)
  (`herdr-core`, `herdr-app`), cached on `cache.numtide.com` only when used
  with their nixpkgs.
- `herdrdev/herdr-nix` (cachix `herdr`) covers only the TUI.

A source-built `hc` is linked against the Nix store, so `hc machine add`
can't copy it to another machine; #581031 downloads upstream's build instead.
Upstream's static Linux binary copies fine. `programs.herdr-app.package` and
`programs.herdr-core.package` take a source build if you'd rather.

Packaging notes:

- **Environment leaks into every terminal.** The app passes its environment to
  herdr-core, which passes it to every terminal it starts. So nothing sets
  `LD_LIBRARY_PATH`: the dlopened Vulkan, Wayland and EGL go on the RUNPATH via
  `runtimeDependencies`. The wrapper adds no PATH and sets only
  `HERDR_TELEMETRY=0` and `HERDR_CORE_DIRS`, which only herdr-app reads.
- **The core is pinned.** The app puts the folder it found hc in first on its
  PATH (upstream `src/core_bin.rs` `use_core`), and every terminal inherits
  it. Left to search, it found `/run/current-system/sw/bin`, which then
  shadowed `/run/wrappers/bin` and broke `sudo` in every pane. The NixOS
  module sets `HERDR_CORE_DIRS` to `programs.herdr-core.package`'s bin, so
  the app finds hc there, and that folder holds only `hc` and `herdr-core`.
  The darwin module, which has no wrapper, writes `core = /etc/herdr-core/hc`
  into settings.json instead: a link to the same package, in a folder that
  holds only hc, at a path with no store hash in it.
- **Self-update is off.** On Linux a release build updates itself only when
  it finds `herdr-app.svg` beside its binary (upstream `src/update.rs`
  `find_root`). The icon lives in `share/icons`, and installCheck fails the
  build otherwise. On macOS any `Herdr.app` bundle is an install root, so the
  updater stays armed, but it stages downloads beside the bundle and
  nix-darwin's copy under `/Applications/Nix Apps` is root-owned: it gets
  EACCES, logs a warning and retries in 30 minutes, only once upstream is
  ahead (and only until the next `update.ts` bump). herdr-core sees its
  `/nix/store/` path (canonicalized, so the `/etc/herdr-core/hc` link counts)
  and refuses `hc update` ("update it in your Nix configuration"), and the
  app never offers updates to such a core.
- **No fixup for herdr-core.** On macOS it is upstream's signed Mach-O, so
  strip or install_name_tool would break the signature. On Linux it is
  static-pie and needs nothing.
- **Linger.** hc starts its core as a transient `systemd-run --user` unit and,
  the first time, turns on linger for the user by itself, so terminals outlive
  logouts. The NixOS module declares it (`programs.herdr-core.linger`, on by
  default) for `programs.herdr-core.users`. Declaring it off doesn't stop hc.
  A lingering user manager starts at boot, and so does everything its
  `default.target` wants, timers included. macOS has no linger: hc starts the
  core as a one-shot launchd job (see "darwin").
- **No core service.** hc spawns the core on demand; a declared unit would
  compete with it.
- **Telemetry** is on by default upstream (a daily usage report). The modules
  and the standalone package turn it off: `HERDR_TELEMETRY=0` from the Linux
  wrapper, `telemetry: false` in settings.json on macOS.

## Modules

`modules/common.nix` declares every option and does what both OSes share.
`modules/nixos.nix` and `modules/darwin.nix` add the parts only their OS can
do.

| Option | NixOS | nix-darwin |
|---|---|---|
| `programs.herdr-cli.{enable,package,nav.enable,python}` | ✓ | ✓ |
| `programs.herdr-core.{enable,package,users,settings}` | ✓ (`settings` → tmpfiles link) | ✓ (`settings` → activation-script link) |
| `programs.herdr-core.linger` | ✓ | — |
| `programs.herdr-app.{enable,package,finalPackage,telemetry,settings,keys}` | ✓ (wrapper: env + merge at launch) | ✓ (`telemetry`, `core`, `settings` merged into settings.json at activation; `keys` → link; `finalPackage` is the bare bundle) |
| `services.herdr-update-check.{enable,package,finalPackage}` | systemd user timer, `calendar` | launchd user agent, `startCalendarInterval` |

`programs.herdr-cli.python` (default `python3`, `null` for none) is for
herdr's agent integration hooks. Claude's `herdr-agent-state.sh` reports the
session id over the herdr socket with python3, and exits silently without it.

## Config files and stow

Each file option defaults to `null`, and then the module leaves the file
alone, so a dotfiles repo can link it in and version it. Herdr's saves write
through symlinks: upstream `src/persist.rs` resolves the link and renames onto
its target, and has tests for exactly that. So a linked `settings.json`,
`keys.json` or layout collects the app's own edits. The core never writes
`config.toml`.

| File (under `~/.config`) | Written by | Module option |
|---|---|---|
| `herdr-core/config.toml` | you only | `programs.herdr-core.settings` → read-only store link |
| `herdr-app/settings.json` | the app (Settings screen, zoom) | `programs.herdr-app.settings` → merged in at each launch (Linux) or each activation (macOS, with `telemetry` and `core`), declared keys win |
| `herdr-app/keys.json` | you; the app writes the defaults if it's missing | `programs.herdr-app.keys` → read-only store link |
| `herdr-app/{themes,layouts,mods}/…` | you, or the app when you duplicate/save one | — |
| `herdr-app/` everything else | the app (shipped mods, `view.json`, telemetry state…) | — |
| `herdr/config.toml` (the TUI) | you | — |

Store links go to each of `programs.herdr-core.users` and replace whatever
is there. On NixOS that's `systemd-tmpfiles` `L+`; on nix-darwin it's
`ln -sfn` from the activation script.

## Updating and upgrade notices

```sh
bun flakes/herdr/update.ts           # rewrite sources.json from upstream's manifests
bun flakes/herdr/update.ts --check   # exit 10 if behind
```

`update.ts` reads `releases.herdr.dev/{core,app}/latest.json`, the manifests
upstream's installers read (there are no GitHub releases, only tags). It
converts their sha256s to SRI, and it refuses a pair where the app's
`core_min` is newer than the core. The relative-path input isn't hash-locked,
so after a rebuild the new pins are live. The TUI moves when you repoint
`herdr-cli.url`.

`herdr-update-check` reports two things:

- **Releases newer than ours:** the fork against GitHub's `releases/latest`
  (prereleases skipped), and the core and app against the manifests.
- **Stale running builds:** a herdr server, core or window older than the
  installed version. A rebuild swaps store paths, not processes. Stop the
  herdr server with `herdr server stop`; move the core with
  `hc server restart`, which keeps your terminals; reopen the window.

Run plain, it prints what's pending and exits 10. With `--notify` it raises
a notification. On Linux that's notify-send with a button per release, after
waiting for a notification daemon. On macOS it's osascript, which has no
buttons. With `--json` it prints one object for programs to read and exits
0: `installed` and `latest` versions per product, and `updates`, each with a
`kind` (`release`, or `running` for a stale process), `from`, `to`, the
changelog or release `url` and the `action` to take (the header of
`pkgs/herdr-update-check.sh` has the shape). The `herdr-updates` mod in the
dotfiles' Herdr layout draws it in the tab bar.

`services.herdr-update-check.enable` schedules it: a `Type=exec` systemd user
unit (see the comment there for why not oneshot), or a launchd agent. Both,
and the copy on PATH, run `finalPackage`: the package with the configured
programs' versions set (`environment`), so a hand run or a `--json` read
compares against what the modules installed rather than this flake's pins.

## darwin

Everything works on the macs. herdr-core is upstream's signed Mach-O, which
`hc machine add` can copy to another Mac as-is. Herdr is upstream's Developer
ID-signed `Herdr.app`, copied whole into `$out/Applications` with no fixup
(installCheck runs `codesign --verify --deep --strict` on the copy), plus
`bin/herdr-app` into the bundle for the CLI (`herdr-app ls|do|status`).
nix-darwin copies `Applications/` of every system package into
`/Applications/Nix Apps`, where Spotlight finds it. The Linux mechanisms
don't reach a bundle Finder launches, so the darwin module does their work
through files instead:

- **Telemetry and the core pin** are settings.json keys (`telemetry`,
  `core`), merged into each core user's `~/.config/herdr-app/settings.json`
  at activation together with `programs.herdr-app.settings`, declared keys
  winning. The core pin is `/etc/herdr-core/hc` (`environment.etc`), a link to
  `programs.herdr-core.package`: a stable path, so a stowed settings.json in
  a repo doesn't collect store hashes. The Settings screen can flip
  telemetry back on until the next rebuild.
- **Self-update** can't be disarmed by layout (a bundle is always a root),
  and isn't editable out of the bundle (that breaks the signature). It is
  defeated by ownership: the staging folder would go beside the bundle under
  `/Applications/Nix Apps`, which root owns and nix-darwin rsyncs
  (`--delete`) on every switch. A warning in the app's log every 30 minutes,
  once upstream is ahead, is the whole cost; herdr-update-check reports the
  same release once a day.
- **No linger; a one-shot launchd job instead.** Since core 0.1.17
  (herdr-app#294) hc starts the core through launchd, because a plain
  detached process stayed in the app's coalition and quitting Herdr killed
  every agent. hc bootstraps a temporary job into `gui/<uid>`, hands the new
  core its own environment over a socket (so the core pin and
  `HERDR_TELEMETRY` still reach every terminal), then boots the job out and
  deletes the plist. Nothing lands in `~/Library/LaunchAgents`, and no store
  path outlives a garbage collection. A core reached over SSH, or one whose
  launchd start fails, still starts as a detached process.
- **The CLI link.** On first launch the app symlinks `~/.local/bin/herdr-app`
  to the bundle's binary (upstream `src/core_bin/cli_link.rs`), unless
  something else is there. It points at nix-darwin's copy, which the next
  switch replaces in place, so it stays current.
- **Stale running builds**: a process started through a symlink (`hc` on
  PATH, `/etc/herdr-core/hc`) names the link in its argv, so on macOS the
  check asks `lsof` for the executable's store path. A core started through
  launchd keeps `--hc-launchd <socket>` as its argv, not `serve`, and the
  check matches both. A window opened from
  Finder runs the copy under `/Applications/Nix Apps`, which carries no
  version, so only a window opened as `bin/herdr-app` from a shell is judged.

The macs' enables live in `modules/darwin/herdr.nix` (one user, one setup);
their config files come from the same `home/herdr-core` and `home/herdr-app`
stow packages as nebula's, so `keys.json` binds ctrl/alt there too, not cmd.

## Files

- `flake.nix`: inputs, including the fork's rationale, and outputs
- `sources.json` + `update.ts`: core and app pins
- `pkgs/`:
  - `herdr-cli.nix`, `herdr-nav.{nix,sh}`
  - `herdr-core.nix`, `herdr-app.nix` (the repacks)
  - `herdr-app-wrap.nix` (the Linux telemetry and settings wrapper),
    `herdr-app-merge-settings.nix` + `merge-settings.sh` (the settings merge
    it and the darwin module share)
  - `herdr-update-check.{nix,sh}`
- `modules/`: `common.nix`, `nixos.nix`, `darwin.nix`
