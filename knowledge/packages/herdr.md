---
type: Sub-flake
title: herdr
description: 'Umbrella sub-flake for everything herdr: our kriswill/herdr TUI fork (herdr-cli) and herdr-nav, upstream''s prebuilt Herdr desktop app and herdr-core (`hc`) repackaged, a herdr-update-check package for Linux and macOS, and the NixOS + nix-darwin modules (programs.herdr-cli/-core/-app, services.herdr-update-check); consumed as inputs.herdr.'
resource: flakes/herdr/
tags: [sub-flake, package, herdr, terminal]
generated: { by: codex/gpt-6.1-sol, at: 2026-11-01T17:07:43-08:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/herdr/README.md
    title: 'flakes/herdr/README.md (outputs, TUI, repacks, modules, config files, updating, darwin)'
  - id: herdr-app-repo
    resource: https://github.com/herdrdev/herdr-app
    title: 'herdrdev/herdr-app (the desktop app: README, install, settings)'
  - id: herdr-core-repo
    resource: https://github.com/herdrdev/herdr-core
    title: 'herdrdev/herdr-core (hc: README, config.toml, machines)'
  - id: app-manifest
    resource: https://releases.herdr.dev/app/latest.json
    title: 'releases.herdr.dev app manifest (version, core_min, per-target URL + sha256)'
  - id: app-update-rs
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.11/src/update.rs
    title: 'herdr-app src/update.rs (find_root: what arms the self-updater)'
  - id: nixpkgs-pr-581031
    resource: https://github.com/NixOS/nixpkgs/pull/581031
    title: 'NixOS/nixpkgs#581031 herdr-core, herdr-desktop: init (source builds; open)'
  - id: app-terminal-0111
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.11/src/terminal.rs
    title: 'Herdr 0.1.11 terminal renderer (cell_size and font glyph rendering)'
  - id: app-braille-renderer
    resource: https://github.com/herdrdev/herdr-app/blob/8cbb9f3348ea802e9c06cca3b413a53d3ba9064e/src/sprites.rs
    title: 'Upstream cell-sized Braille sprite renderer, present after 0.1.11'
---

One flake for three products and their tools
([decision](../decisions/herdr-umbrella-subflake.md)):

- **The herdr TUI** (`herdr-cli`), from our fork's own flake, with the build
  identity stamped in (`pkgs/herdr-cli.nix`). The fork's rationale and rebase
  procedure live on the input in `flake.nix`; see [herdr](../modules/herdr.md).
- **herdr-core** (`hc`), which runs terminals and agents in a per-user daemon
  that outlives its viewers.[^herdr-core-repo]
- **Herdr** (`herdr-app`), the window that arranges them, drawing with wgpu
  over Vulkan.[^herdr-app-repo]

Core and app are upstream's release tarballs, pinned in `sources.json` from
the manifests the installers read, and bumped by `update.ts`.[^app-manifest]
Nothing compiles, so there's nothing to cache
([decision](../decisions/herdr-app-release-repack.md)).

Outputs (`x86_64-linux`, `aarch64-linux`, `aarch64-darwin`):

- `herdr-cli` (`default`): the TUI, the same derivation `pkgs.herdr` was
  before the move.
- `herdr-nav`: [herdr-nav](herdr-nav.md), with `herdr-cli` pinned in.
- `herdr-core`: the static-pie binary on Linux, or upstream's signed Mach-O
  on macOS. Both are installed with no fixup at all, plus an `hc` link.
- `herdr-app-unwrapped`: on Linux autoPatchelf'd, with the dlopened Vulkan,
  Wayland and EGL on its RUNPATH; on macOS upstream's signed `Herdr.app`
  copied whole into `Applications/`, no fixup, `bin/herdr-app` into the
  bundle for the CLI ([decision](../decisions/herdr-app-darwin-bundle.md)).
- `herdr-app`: `pkgs/herdr-app-wrap.nix`, which sets `HERDR_TELEMETRY=0` and
  puts this core at the end of PATH for `nix run` (a shell launch; on macOS
  Finder launches the bundle and bypasses it).
- `herdr-update-check`, which reports two kinds of staleness:
  - **Upstream releases** past ours: the fork against GitHub
    `releases/latest`, the core and app against the manifests.
  - **Stale running builds**, read off their executables' store paths (argv
    on Linux; `lsof` on macOS, where a symlink-started process names the
    link): a herdr server (`herdr server stop`), a core (`hc server
    restart`), a window (reopen it; a Finder-launched one on macOS runs
    nix-darwin's unversioned copy and can't be judged).

  By default it prints and exits 10. With `--notify` it sends notify-send
  with a button per release, or osascript on macOS.
- `nixosModules.herdr` and `darwinModules.herdr`: `modules/common.nix` plus
  per-OS layers, re-exported by [herdr](../modules/herdr.md).

Gotchas:

- **Environment leaks into every terminal.** The app hands its environment to
  the core, which hands it to every terminal. So nothing sets
  `LD_LIBRARY_PATH`, and the modules add no PATH (nixpkgs#581031 hit the
  same issue).[^nixpkgs-pr-581031] Herdr still leads that PATH with the
  folder it found hc in, so the modules pin the lookup to the core's own bin
  (`HERDR_CORE_DIRS`). Left to search, the system profile went first and
  broke `sudo` in every pane
  ([decision](../decisions/herdr-app-pin-core-dir.md)).
- **The self-updater is off by layout** on Linux: a release build updates
  itself only when `herdr-app.svg` sits beside its binary.[^app-update-rs]
  The icon goes in `share/icons`, and installCheck fails the build if it's
  beside the binary. On macOS a bundle is always a root, so it's off by
  ownership instead: the staging folder would go beside the bundle under
  root-owned `/Applications/Nix Apps` (EACCES, a warning every 30 minutes
  once upstream is ahead). A `/nix/store` hc refuses `hc update`, and the
  app never offers to update it.
- **hc enables linger by itself** the first time it starts a core, and the
  NixOS module declares it. The prototype's test core turned it on for k on
  2026-11-01; that was reverted.
- **Herdr on darwin** was asserted off until 2026-11-01, when the wrapper's
  two jobs turned out to be settings.json keys (`telemetry`, `core`) that
  the darwin module can write at activation, and the updater's failure
  turned out to be harmless.[^subflake-readme]
  ([decision](../decisions/herdr-app-darwin-bundle.md))
- **Lock parity.** The move kept the fork's lock node and its rust-overlay rev
  (`577bb1e`, which follows our nixpkgs). Re-lock with `--override-input
  herdr/herdr-cli/rust-overlay` if a fresh lock jumps it.

## Braille row gaps — checked 2026-11-01

Herdr-app 0.1.11 shows horizontal bands between rows of Braille art, also
reproduced with consecutive rows of `⣿` (U+28FF). The live window used
MesloLGS Nerd Font at an effective 15.3 px. This release renders Braille as
font glyphs; `cell_size` multiplies the font's ascent plus absolute descent
by 1.15 and rounds up to device pixels. The dots do not fill that row
height, leaving visible vertical gaps. There is no exposed line-spacing
setting in this version.[^app-terminal-0111]

Upstream source at `8cbb9f3` includes a custom Braille sprite renderer,
using Ghostty's integer-pixel dot layout sized to each terminal cell,
instead of font glyphs.[^app-braille-renderer] This is the pending remedy;
it has not been visually tested here. The release-manifest check
(`bun flakes/herdr/update.ts --check`) still reported app 0.1.11 and core
0.1.16 as current on 2026-11-01, so the Nix pins were left unchanged.

On the next app release, confirm its source contains the Braille renderer,
run `bun flakes/herdr/update.ts`, build/rebuild, and reopen the window.
Verify consecutive rows of `⣿` and the original artwork in a live pane.
Keep the [release repackaging approach](../decisions/herdr-app-release-repack.md)
rather than assuming a source fix is already in a released tarball.

## Source

- Flake: [`flakes/herdr/`](../../flakes/herdr/)
- README: [`flakes/herdr/README.md`](../../flakes/herdr/README.md)

Consumed by the root flake as a relative-path input; see the
[sub-flake extraction pattern](../patterns/subflake-extraction.md). Mounted on
every host by [herdr](../modules/herdr.md). The app and core are enabled on
[nebula](../hosts/nebula.md) by [nebula-herdr](../modules/nebula-herdr.md)
and on every mac by the darwin twin itself; both OSes' config files belong
to the `home/herdr-core` and `home/herdr-app` stow packages
([decision](../decisions/herdr-app-config-via-stow.md)).

[^subflake-readme]: `flakes/herdr/README.md`: outputs, packaging notes, darwin
[^herdr-app-repo]: herdrdev/herdr-app README
[^herdr-core-repo]: herdrdev/herdr-core README
[^app-manifest]: releases.herdr.dev/app/latest.json, the installers' manifest
[^app-update-rs]: herdr-app `src/update.rs`, `find_root` and `checks_app`
[^app-terminal-0111]: Herdr 0.1.11 `src/terminal.rs`, `cell_size` and row rendering
[^app-braille-renderer]: Upstream `src/sprites.rs`, `braille`, `is_sprite` and `paint`
[^nixpkgs-pr-581031]: NixOS/nixpkgs#581031 notes for review: "No wrapper for herdr-desktop"
