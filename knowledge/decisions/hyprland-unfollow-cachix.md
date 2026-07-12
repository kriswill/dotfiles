---
type: Decision
title: Hyprland Un-follows Nixpkgs and Substitutes From hyprland.cachix.org
description: 'The hyprland input no longer follows our nixpkgs and nebula consumes inputs.hyprland.packages directly instead of the hyprland-packages/hyprland-extras overlays, with hyprland.cachix.org wired as a substituter (nebula daemon, CI nebula job, flake nixConfig) — the hypr* stack downloads instead of source-building whenever our nixpkgs is drv-equivalent to upstream''s lock, and hyprpolkitagent de-taints back to Hydra-cached nixpkgs drvs.'
tags: [nix, cache, hyprland, ci]
timestamp: '2026-07-12T08:30:00Z'
---

**Status:** active. **Where:** `flake.nix` (hyprland input + `nixConfig`),
[hyprland](../modules/hyprland.md)
(`modules/hosts/nebula/hyprland.nix`), `modules/overlays.nix`,
[dotfiles-stow](../modules/dotfiles-stow.md), `.github/workflows/ci.yml`
(nebula job `extra-conf`); manual: [`docs/hyprland.md`](../../docs/hyprland.md).

## Context

The weekly flake bump cost the CI nebula job a 1–2 h source build of the
hypr* stack. Investigating "can we add a trusted cache?" surfaced three facts
(all machine-verified 2026-07-12):

- upstream runs hyprland.cachix.org, but nebula consumed hyprland through
  `inputs.hyprland.overlays.hyprland-packages` — rebuilt against OUR nixpkgs,
  structurally unable to match what upstream CI pushes;
- the overlay's globally-bumped `hyprutils` tainted unrelated nixpkgs
  packages: `hyprpolkitagent` was rebuilt into a drv cached NOWHERE (404 on
  both cache.nixos.org and the cachix), and the same mechanism had repeatedly
  broken hyprlock builds (see `docs/hyprland.md` learned behaviours);
- surprisingly, the overlay-built hyprland drv WAS on the cachix that week —
  our nixpkgs (e7a3ca8) and upstream's lock (0bb7ec5) were 1,570 commits
  apart yet drv-equivalent for hyprland's whole build closure. The 2 h builds
  were happening only because nothing subscribed to the cache.

## Decision

- **Un-follow:** `inputs.hyprland` no longer follows our nixpkgs. Note the
  learned limitation: `nix flake lock` resolves the un-followed dep **fresh
  from nixos-unstable HEAD**, NOT from hyprland's own lock — so cache hits
  are *probabilistic* (drv-equivalence between nearby unstable revs, i.e.
  most weeks), not structural. On a miss week (staging mass-rebuild in the
  gap) CI source-builds once and FlakeHub serves it on, same as before.
- **Direct packages, no overlays:** `programs.hyprland.{package,portalPackage}`
  = `inputs.hyprland.packages.*.{hyprland,xdg-desktop-portal-hyprland}`; the
  `hyprland-packages`/`hyprland-extras` overlay registrations are deleted.
  `hyprpolkitagent` and friends revert to pure nixpkgs drvs (Hydra-cached,
  verified 200), and the hyprutils-outpaces-nixpkgs breakage class is closed.
  The stow activation script's `hyprctl` reference moved from `pkgs.hyprland`
  to `config.programs.hyprland.package` so the closure doesn't regain a
  second hyprland from nixpkgs.
- **Substituter wired three ways:** nebula's daemon
  (`nix.settings.{substituters,trusted-public-keys}`), the CI nebula job
  (`determinate-nix-action` `extra-conf` — the darwin job is untouched, its
  closure never contains the stack; runners ignore flake `nixConfig` as
  untrusted), and flake `nixConfig` (trusted interactive callers).

## Consequences

- Weekly bump PRs stop paying the hypr* source build on cache-aligned weeks;
  nebula's `nrs` likewise pulls prebuilt (from cachix or FlakeHub, whichever
  answers first).
- Verified at adoption: hyprland and xdph outPaths return 200 from the
  cachix; hyprland's outPath was byte-identical to the overlay build that
  week (same nixpkgs rev); full drv-graph hypr inventory contains only the
  flake stack (cachix-served) plus pure-nixpkgs deps (Hydra-served); nebula
  toplevel and darwin k both eval green; no measurable eval-time penalty.
- The drv graph carries two `hyprutils`/`hyprlang` instances (flake's for
  hyprland, nixpkgs' for hyprpolkitagent) — both substitutable, small.
- Watch: hyprland's flake HEAD version string can mislead
  (`hyprctl version` is authoritative); a future second NixOS host would
  inherit the `nix.settings` pair only via nebula's host file, deliberately.
- Watch: if upstream stops pushing per-commit builds or rotates the cachix
  key, the pair must be updated in all three wiring points.

## Citations

- [Hyprland wiki: Cachix page (cache URL + key, "do not override nixpkgs")](https://wiki.hypr.land/Nix/Cachix/)
- [ci-github-actions](ci-github-actions.md) — the revised accepted-cost
  bullet; the FlakeHub fallback this decision layers on.
- Commits `2c9e134` (branch `hyprland-drop-follows`) and the adoption PR.
