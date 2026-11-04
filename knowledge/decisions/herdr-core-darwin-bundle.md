---
type: Decision
title: Ship herdr-core on the Macs as Upstream's Signed Herdr Core.app, in libexec
description: 'From core 0.1.18 the macOS release tarball carries a Developer ID-signed Herdr Core.app beside the bare binary. The package installs the bundle whole under $out/libexec and links bin/herdr-core and bin/hc into it, because macOS privacy (local network, microphone) for terminal programs is credited to the core and only an executable inside the bundle carries the usage descriptions. libexec, not Applications, keeps an LSUIElement helper out of Spotlight and /Applications/Nix Apps.'
tags: [herdr, darwin, packaging, tcc]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-11-04T12:30:00-08:00 }
sources:
  - id: core-changelog
    resource: https://github.com/herdrdev/herdr-core/blob/v0.1.18/CHANGELOG.md
    title: 'herdr-core 0.1.18 changelog (On macOS, the core is now its own app, Herdr Core; #100)'
  - id: core-macos-bundle-rs
    resource: https://github.com/herdrdev/herdr-core/blob/v0.1.18/crates/herdr-core/src/platform/macos_bundle.rs
    title: 'herdr-core platform/macos_bundle.rs (bundle(): exe must be exactly Herdr Core.app/Contents/MacOS/herdr-core; needs_bundle_update skips package-manager installs)'
  - id: core-responsibility-rs
    resource: https://github.com/herdrdev/herdr-core/blob/v0.1.18/crates/herdr-core/src/platform/macos_responsibility.rs
    title: 'herdr-core platform/macos_responsibility.rs (core and holders disclaim privacy responsibility)'
  - id: core-machines-rs
    resource: https://github.com/herdrdev/herdr-core/blob/v0.1.18/crates/herdr-core/src/machines.rs
    title: 'herdr-core machines.rs (machine add canonicalizes current_exe and packs the whole bundle)'
  - id: subflake-readme
    resource: ../../flakes/herdr/README.md
    title: 'flakes/herdr/README.md (darwin)'
---

**Where:** the [herdr sub-flake](../packages/herdr.md)'s `pkgs/herdr-core.nix`
(and the stale-core match in `pkgs/herdr-update-check.sh`). Extends
[herdr-app-darwin-bundle](herdr-app-darwin-bundle.md), which covers the app.

## Context

Up to 0.1.17 the macOS core tarball held one signed Mach-O, installed as
`bin/herdr-core`. In 0.1.18 the core became its own app:[^core-changelog] the
tarball adds `Herdr Core.app` (`dev.herdr.core`, `LSUIElement`, entitlements
for audio input, camera and so on, and an Info.plist full of
`NS…UsageDescription` keys), and keeps a separately signed bare `herdr-core`
beside it for older updaters.

The core and every holder disclaim privacy responsibility when they
spawn,[^core-responsibility-rs] so macOS credits a request from any program
in a terminal (Node reaching a LAN model server, a voice tool opening the
mic) to the core's own executable. Only an executable inside the bundle has
the usage descriptions. Run bare, local network and microphone access stay
broken, which is the bug 0.1.18 fixes.

## Decision

On darwin, copy `Herdr Core.app` whole into `$out/libexec/`, link
`bin/herdr-core` to its `Contents/MacOS/herdr-core` and `bin/hc` to that,
and skip the bare binary. installCheck runs `codesign --verify --deep
--strict` on the copy, as `herdr-app.nix` does for `Herdr.app`. Linux is
unchanged: its tarball is still the static-pie binary alone.

- **libexec, not Applications.** `Applications/` would make nix-darwin
  rsync a second copy into `/Applications/Nix Apps`, where Spotlight lists
  a "Herdr Core" that does nothing useful when opened. Every running core
  starts from the store path, through `/etc/herdr-core/hc` or `hc` on PATH,
  so that copy would never run. Upstream runs `lsregister -f` on its own
  installs, perhaps so the prompt shows "Herdr Core". The changelog warns
  the network prompt may say "herdr-core" anyway, so skipping LaunchServices
  costs at most a label.
- **Links are enough.** upstream finds the bundle from its canonicalized
  path: `bundle()` wants exactly `Herdr Core.app/Contents/MacOS/herdr-core`,[^core-macos-bundle-rs]
  `hc machine add` canonicalizes and then packs the whole bundle,[^core-machines-rs]
  and `installed_by` still sees `/nix/store/`, so `hc update` still refuses
  and `needs_bundle_update` (the "run hc update to finish installing" notice)
  stays quiet.
- **Grants survive bumps.** TCC keys a grant on the code signature's
  designated requirement (identifier plus team `2W9652Q7QR`), not on the
  path. A new store path per version doesn't re-prompt for that reason.

## Consequences

- `herdr-update-check` reads the core's version off its executable, which
  `lsof` now reports inside the bundle. Its regex accepts both
  `bin/(herdr-core|hc)` and `libexec/Herdr Core.app/Contents/MacOS/herdr-core`.
- Terminals started under a pre-0.1.18 core keep the old privacy context.
  `hc server restart` moves the core but not their holders: recreate those
  terminals once.
- The first network or mic use after the switch prompts once each. Grants
  given to `Herdr.app` don't carry over to the core.

[^core-changelog]: herdr-core 0.1.18 `CHANGELOG.md`: "On macOS, the core is now its own app, Herdr Core" (#100)
[^core-responsibility-rs]: herdr-core `src/platform/macos_responsibility.rs`: `holder_startup`, `exec` (`responsibility_spawnattrs_setdisclaim`)
[^core-macos-bundle-rs]: herdr-core `src/platform/macos_bundle.rs`: `bundle`, `core_executable`, `needs_bundle_update`
[^core-machines-rs]: herdr-core `src/machines.rs`: canonicalized `current_exe`, `core-bundle.tar` of `Herdr Core.app`
