---
type: Decision
title: Unify nebula-snowglobe and main Into One Dual-OS Flake
description: Merged the orphan NixOS branch into main with --allow-unrelated-histories — one flake builds three darwin hosts and nebula; single nixpkgs on nixos-unstable (pinned at merge to nebula's rev), nebula's packages/ dissolved into pkgs/ + overlays, and the two class realisers (darwin.nix / nixos.nix) coexist unchanged.
tags: [nix, architecture, nixos, darwin, merge]
timestamp: '2026-07-03T14:00:00-07:00'
---

**Status:** active. **Where:** [flake.nix](../../flake.nix),
[modules/nixos.nix](../../modules/nixos.nix), [modules/packages.nix](../../modules/packages.nix),
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Context

`main` (nix-darwin, 3 Macs) and `nebula-snowglobe` (orphan branch, one NixOS
desktop on snowglobe-lib) shared the dendritic skeleton by design — the
[remove-option-gating](remove-option-gating.md) refactor explicitly aligned
main's layout with nebula's so "a merge drops the trees side by side with zero
path collisions". Time to actually merge: many CLI tools (nvim, tmux, zsh, git,
ghostty, starship…) were configured near-identically on both branches, drifting
apart with every commit.

## Decision

- **History:** `git merge --allow-unrelated-histories` on the
  `nixos-darwin-combined` branch — nebula's 140 commits stay reachable and
  blame-able. Rejected: re-committing the tree (orphans the history).
- **nixpkgs:** one input, channel `nixos-unstable` — the same package set as
  `nixpkgs-unstable` but gated on the NixOS test suite; safe for darwin (lags a
  few days), required regression cover for nebula. Rejected: two nixpkgs inputs
  (double lock churn, two store universes). At merge time the lock is pinned to
  nebula's prior rev (`e73de5b`) so nebula rebuilds byte-stable; darwin absorbs
  the channel switch. Bump normally afterwards.
- **Pinned nixos-side inputs:** `snowglobe-lib`/`hyprland`/`noctalia`/`tomato`
  locked at nebula's revs — snowglobe-lib's unstable HEAD had already renamed
  `snowglobe-lib.libvirtd-qemu` → `snowglobe-lib.qemu`; bumping it is its own
  change, not the merge's.
- **Custom packages:** nebula's `packages/` aggregator dissolved into `pkgs/`
  per the documented convention (one file per package + one overlay file each);
  `wowPath` defaults inside `pkgs/wowup.nix` so the overlay and the packages
  output can't drift. Platform-bound packages sit under `lib.optionalAttrs`
  guards in `modules/packages.nix`; `overlays/podman.nix` is internally
  platform-guarded (darwin gets the prebuilt remote client, Linux keeps
  nixpkgs' podman) because every host applies the whole overlay set.
- **Realisers coexist:** `modules/darwin.nix` (darwinSystem + extendedLib) and
  `modules/nixos.nix` (snowglobe-lib `mkNixosHost`, hardware metadata in the
  registry) stay separate files — isomorphic shape, different builders. The
  nixos evaluation does not get the extended lib; nixos modules import `lib/`
  files by path (see `lib/direnv-nom-wrapper.nix`).
- **nixos modules stay ungated:** with a single Linux host, every
  `flake.modules.nixos.*` is universal-within-class (matches the pattern's
  intent). Retrofit `programs./services.` gates when a second NixOS host
  appears — a desktop-stack module set on a future headless host would be the
  trigger.
- **config/ stays nebula-only:** the Helium/Noctalia snapshot mechanism
  (capture/restore CLIs, age-encrypted) is Linux-scoped. Extending Helium to
  macOS would need: the macOS profile dir
  (`~/Library/Application Support/net.imput.helium`), per-host snapshot
  subtrees for the os_crypt-bound SQLite files (Cookies/Login Data restore only
  on the machine that captured them), and multi-recipient age encryption.
  Deliberately not built until Helium actually runs on a Mac.

## Consequences

One `nix flake check` covers all four hosts (`configurations:darwin:*` build on
the Macs; `configurations:nixos:nebula` evaluates there and builds on nebula).
Shared stow content can no longer drift per-OS — divergence must be explicit
(skip lists, per-OS `os.conf` halves, includeIf branches). nebula's checkout
must switch from the `nebula-snowglobe` branch to the merged branch/main on its
next pull.
