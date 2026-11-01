---
type: Decision
title: Gather Everything Herdr into One Sub-flake
description: 'flakes/herdr is the umbrella for all herdr-related packages, scripts and configuration — the TUI fork (moved from a root input + overlay), herdr-nav (from pkgs/), herdr-core and Herdr, one herdr-update-check (absorbing nebula''s fork check) — exposing programs.herdr-cli/-core/-app and services.herdr-update-check through both NixOS and nix-darwin modules, with drv parity for the TUI.'
tags: [herdr, sub-flake, structure]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-11-01T14:00:00-08:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/herdr/README.md
    title: 'flakes/herdr/README.md (outputs, modules)'
---

**Where:** [herdr sub-flake](../packages/herdr.md), [herdr](../modules/herdr.md),
[nebula-herdr](../modules/nebula-herdr.md).

## Context

On 2026-11-01, before its first switch, the new Herdr app and herdr-core
sub-flake (`flakes/herdr-app`) sat beside a herdr story scattered across the
repo:

- the TUI fork as a root `herdr` input, with its build identity in
  `modules/overlays.nix`;
- `herdr-nav` in `pkgs/` with its own overlay;
- two class modules that just listed packages;
- a fork-only update check in nebula's host config.

The user asked for one umbrella named `herdr`. The TUI should be a
multi-platform `programs.herdr-cli` mount point, and `programs.herdr-core` /
`programs.herdr-app` should be configured through each OS's module options.
Stow wiring stays outside the flake.

## Decision

- **Layout.** `flakes/herdr/` holds `pkgs/` (one file per package), `modules/`
  (`common.nix` declares every option and the OS-independent config;
  `nixos.nix` and `darwin.nix` add linger, tmpfiles and systemd, or
  activation links and launchd), plus `sources.json` and `update.ts`.
- **The fork becomes the sub-flake's `herdr-cli` input.** The rust-overlay
  override now spells out its nixpkgs follow, which a CLI `--override-input`
  had dropped. `pkgs/herdr-cli.nix` keeps the build identity.
- **Root wiring.** `pkgs.herdr` stays as an inline overlay of `herdr-cli`,
  because hermes-agent takes `mkPackageOption pkgs "herdr"`. (That option
  went away with the
  [TypeScript integration](hermes-herdr-integration-shell-hook.md), and the
  overlay was removed on 2026-11-01; no host's system drv changed.) The `herdr-nav`
  overlay is gone; the module installs herdr-nav with the configured herdr
  pinned in. `modules/{nixos,darwin}/herdr.nix` each import their OS's module
  and set `programs.herdr-cli.enable = true`, which keeps the TUI on every
  host.
- **One `herdr-update-check`** covers the fork, the core and the app, both
  upstream and stale running builds. It's scheduled per OS
  (`services.herdr-update-check`: a systemd user timer or a launchd agent).
  It took over nebula's fork-only unit under the same name, and the host
  files went away.
- **Darwin scope.** herdr-cli, herdr-nav, herdr-core and the check work on
  the macs. `programs.herdr-app` asserts off there, because the signed bundle
  can't take the telemetry wrapper and its updater would fail against the
  store.[^subflake-readme] The macs enable only herdr-cli for now.

## Consequences

- **Parity.** The TUI drv is unchanged on nebula and `k`
  (`…4axnjgpz…-herdr-0.9.5.drv`, `…npxybql…-herdr-0.9.5.drv`), and so are
  herdr-nav and python3. The root lock's other nodes are identical, and the
  fork's node is the same content renamed to `herdr-cli`. A fresh relock of
  the umbrella should pin `herdr/herdr-cli/rust-overlay` to keep that.
- **Rebasing the fork** now means repointing `flakes/herdr/flake.nix`'s
  `herdr-cli.url`, not the root's.
- **Option surface.** `programs.herdr-core.linger` and the update check's
  schedule (`calendar` / `startCalendarInterval`) are the only per-OS
  options.
- Landed in commit `4de98e9`.

[^subflake-readme]: `flakes/herdr/README.md`: modules; darwin
