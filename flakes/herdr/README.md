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
| `packages.herdr-app-unwrapped` | Linux | Herdr (GPUI + wgpu): upstream's release build, patchelf'd |
| `packages.herdr-app` | Linux | the app with telemetry off and this core at the end of PATH, for `nix run` |
| `packages.herdr-update-check` | all | is any of these behind upstream, or running a stale build? |
| `nixosModules.herdr` (`default`) | | `programs.herdr-{cli,core,app}`, `services.herdr-update-check` |
| `darwinModules.herdr` (`default`) | | the same options (herdr-app asserts off) |

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
runs patchelf, all in seconds. Upstream releases about daily, and `update.ts`
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
  `runtimeDependencies`. The modules add no PATH either, since the app looks
  for hc in `/run/current-system/sw/bin` itself. The wrapper sets only
  `HERDR_TELEMETRY=0`, which only herdr-app reads.
- **Self-update is off.** A release build updates itself only when it finds
  `herdr-app.svg` beside its binary (upstream `src/update.rs` `find_root`). The
  icon lives in `share/icons`, and installCheck fails the build otherwise.
  herdr-core sees its `/nix/store/` path and refuses `hc update` ("update it in
  your Nix configuration"), and the app never offers updates to such a core.
- **No fixup for herdr-core.** On macOS it is upstream's signed Mach-O, so
  strip or install_name_tool would break the signature. On Linux it is
  static-pie and needs nothing.
- **Linger.** hc starts its core as a transient `systemd-run --user` unit and,
  the first time, turns on linger for the user by itself, so terminals outlive
  logouts. The NixOS module declares it (`programs.herdr-core.linger`, on by
  default) for `programs.herdr-core.users`. Declaring it off doesn't stop hc.
  A lingering user manager starts at boot, and so does everything its
  `default.target` wants, timers included. macOS has no linger: hc starts the
  core as a plain detached process.
- **No core service.** hc spawns the core on demand; a declared unit would
  compete with it.
- **Telemetry** is on by default upstream (a daily usage report). The modules
  and the standalone package turn it off.

## Modules

`modules/common.nix` declares every option and does what both OSes share.
`modules/nixos.nix` and `modules/darwin.nix` add the parts only their OS can
do.

| Option | NixOS | nix-darwin |
|---|---|---|
| `programs.herdr-cli.{enable,package,nav.enable,python}` | ✓ | ✓ |
| `programs.herdr-core.{enable,package,users,settings}` | ✓ (`settings` → tmpfiles link) | ✓ (`settings` → activation-script link) |
| `programs.herdr-core.linger` | ✓ | — |
| `programs.herdr-app.{enable,package,finalPackage,telemetry,settings,keys}` | ✓ | asserts `enable = false` |
| `services.herdr-update-check.{enable,package}` | systemd user timer, `calendar` | launchd user agent, `startCalendarInterval` |

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
| `herdr-app/settings.json` | the app (Settings screen, zoom) | `programs.herdr-app.settings` → merged in at each launch, declared keys win |
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
buttons. `services.herdr-update-check.enable` schedules it: a `Type=exec`
systemd user unit (see the comment there for why not oneshot), or a launchd
agent.

## darwin

herdr-cli, herdr-nav, herdr-core and the update check all work there. Herdr
itself doesn't yet. Upstream's macOS app is a Developer ID–signed `Herdr.app`,
and both of our Linux mechanisms fail on it:

- **Telemetry:** the wrapper can't reach a bundle launched from Finder, and
  editing the bundle would break its signature.
- **Self-update:** the updater would find the bundle and fail against the
  read-only store every 30 minutes.

So `darwinModules.herdr` asserts `programs.herdr-app.enable = false`.

## Files

- `flake.nix`: inputs, including the fork's rationale, and outputs
- `sources.json` + `update.ts`: core and app pins
- `pkgs/`:
  - `herdr-cli.nix`, `herdr-nav.{nix,sh}`
  - `herdr-core.nix`, `herdr-app.nix` (the repacks)
  - `herdr-app-wrap.nix` + `merge-settings.sh` (the telemetry and settings
    wrapper)
  - `herdr-update-check.{nix,sh}`
- `modules/`: `common.nix`, `nixos.nix`, `darwin.nix`
