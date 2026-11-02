---
type: Decision
title: Ship Herdr on the Macs as Upstream's Signed Bundle, Configured Through settings.json
description: 'programs.herdr-app works on nix-darwin by installing upstream''s Developer ID-signed Herdr.app untouched and doing the Linux wrapper''s two jobs through files instead: telemetry and the core pin are settings.json keys the module merges at activation, the core pin is the stable /etc/herdr-core/hc link, and the self-updater is left armed because root-owned /Applications/Nix Apps denies its staging folder.'
tags: [herdr, darwin, packaging]
status: stable
generated: { by: claude-code/fable-5.1, at: 2026-11-01T18:30:00-08:00 }
sources:
  - id: app-settings-rs
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.11/src/settings.rs
    title: 'herdr-app src/settings.rs (Person: telemetry, core)'
  - id: app-core-bin-rs
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.11/src/core_bin.rs
    title: 'herdr-app src/core_bin.rs (find: configured core first; cli_link)'
  - id: app-update-rs
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.11/src/update.rs
    title: 'herdr-app src/update.rs (find_root: any .app bundle; beside: staging next to the root)'
  - id: core-client-rs
    resource: https://github.com/herdrdev/herdr-core/blob/v0.1.16/crates/herdr-core/src/client.rs
    title: 'herdr-core src/client.rs (installed_by canonicalizes before matching /nix/store/)'
  - id: nix-darwin-applications
    resource: https://github.com/nix-darwin/nix-darwin/blob/ff0e21a414d4547183396da1b44a66f2577b65e9/modules/system/applications.nix
    title: 'nix-darwin modules/system/applications.nix (rsync --delete --chmod=-w into /Applications/Nix Apps)'
  - id: subflake-readme
    resource: ../../flakes/herdr/README.md
    title: 'flakes/herdr/README.md (darwin)'
---

**Where:** the [herdr sub-flake](../packages/herdr.md)'s `pkgs/herdr-app.nix`
and `modules/darwin.nix`; the [herdr module](../modules/herdr.md)'s darwin
twin, which enables it on every mac. Supersedes the darwin scope of
[herdr-umbrella-subflake](herdr-umbrella-subflake.md).

## Context

The umbrella shipped with `programs.herdr-app` asserted off on nix-darwin.
Upstream's macOS build is a Developer ID-signed `Herdr.app`, and the two
things the Linux wrapper does looked impossible on it: a wrapper script
doesn't reach a bundle Finder launches, editing the bundle (Info.plist
`LSEnvironment`, say) breaks its signature, and the self-updater can't be
disarmed by layout since any `.app` grandparent counts as an install
root.[^app-update-rs] It would then fail against the read-only store every
30 minutes.

Reading the app settled each point:

- `telemetry` and `core` are `settings.json` keys.[^app-settings-rs] A
  configured `core` is the first place the app looks for hc, before
  `HERDR_CORE_DIRS` and PATH.[^app-core-bin-rs] The wrapper's environment
  was never the only route.
- The updater stages a download *beside* its root
  (`Herdr.app.download.noindex`).[^app-update-rs] nix-darwin copies every
  system package's `Applications/` into `/Applications/Nix Apps` as root,
  read-only, with `rsync --delete` on every switch.[^nix-darwin-applications]
  The user's app can't create anything there: one warning, a retry in 30
  minutes, only while upstream is ahead of `sources.json`.
- hc canonicalizes its own path before looking for `/nix/store/`, so a
  symlink to it still counts as nix-managed and gets no `hc update`
  offers.[^core-client-rs]

## Decision

- `pkgs/herdr-app.nix` builds on `aarch64-darwin` too: `stdenvNoCC`,
  `sourceRoot = "."`, `cp -R Herdr.app $out/Applications/`, `dontFixup`
  (strip or install_name_tool would break the signature), `bin/herdr-app`
  into the bundle for the CLI, and installCheck runs
  `codesign --verify --deep --strict` on the copy. `update.ts` pins the
  `macos-aarch64` app target alongside the core's.
- On darwin `finalPackage` is the bare bundle. `modules/darwin.nix` merges
  `{ telemetry = false; core = "/etc/herdr-core/hc"; } // settings` into
  each core user's `~/.config/herdr-app/settings.json` at activation (order
  1600, after the stow at 1500, as the user, through a symlink), with the
  same `herdr-app-merge-settings` script the Linux wrapper runs at launch.
  `keys` becomes an `ln -sfn` link like the core's `config.toml`.
- The core pin is `environment.etc."herdr-core/hc"`, a link to
  `programs.herdr-core.package`. The folder holds only hc, so Herdr leading
  every pane's PATH with it shadows nothing (the point of
  [herdr-app-pin-core-dir](herdr-app-pin-core-dir.md)), and the path has no
  store hash, so the stowed repo copy of settings.json doesn't churn on core
  bumps (the objection that decision raised to `settings.core`). The repo
  file carries the key already; on nebula the path doesn't exist, so the
  lookup falls through to `HERDR_CORE_DIRS` as before.
- The self-updater is left armed. Ownership defeats it; nothing is edited.
- `herdr-update-check` reads a running process's store path from `lsof` on
  macOS, since a process started through a symlink (`hc` on PATH, the pin)
  names the link in its argv. A window Finder launched runs the unversioned
  copy under `/Applications/Nix Apps` and isn't judged.
- The macs' enables (`programs.herdr-app.enable`,
  `programs.herdr-core.users = [ "k" ]`, `services.herdr-update-check.enable`)
  sit in `modules/darwin/herdr.nix`, the universal darwin twin, since every
  mac has the one user and the same setup. `home/herdr-app` and
  `home/herdr-core` left the darwin stow skip list, so the macs share
  nebula's files ([stow decision](herdr-app-config-via-stow.md)); keys.json
  therefore binds ctrl/alt on the macs too.

## Consequences

- `nix build .#darwinConfigurations.k.system` passes; nebula's `herdr-app`
  and `herdr-core` derivations are unchanged (only `herdr-update-check`
  moved, for the lsof change).
- The Settings screen can turn telemetry back on until the next rebuild;
  on Linux the environment variable wins regardless.
- The app's first launch links `~/.local/bin/herdr-app` to nix-darwin's copy
  of the bundle (upstream's CLI link),[^app-core-bin-rs] which the next
  switch replaces in place; harmless, and the same version as `bin/herdr-app`.
- An app bump that renames `telemetry` or `core`, or stages updates
  somewhere writable, would reopen the question; `flakes/herdr/README.md`
  "darwin" is the place to check first.[^subflake-readme]

[^app-settings-rs]: herdr-app `src/settings.rs`: `Person` (`telemetry`, `core`), `telemetry_setting`
[^app-core-bin-rs]: herdr-app `src/core_bin.rs`: `find` (configured core first), `install_cli_link` / `cli_link.rs`
[^app-update-rs]: herdr-app `src/update.rs`: `find_root` (macOS: the `.app` bundle), `beside` (staging next to the root), `check_from`
[^core-client-rs]: herdr-core `src/client.rs`: `installed_by` canonicalizes, `manager_of` matches `/nix/store/`
[^nix-darwin-applications]: nix-darwin `modules/system/applications.nix`: rsync into `/Applications/Nix Apps`
[^subflake-readme]: `flakes/herdr/README.md`: darwin
