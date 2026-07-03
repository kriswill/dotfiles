---
type: Decision
title: Remove Option Gating; Mount Modules Into Hosts
description: Dropped every kriswill.<feature>.enable toggle and lib.mkIf gate — a module mounted into a host is active; host selection moved from option flips to file placement, mirroring the nebula-snowglobe NixOS branch for a clean future merge.
tags: [nix, module, architecture]
timestamp: '2026-07-03T10:30:00-07:00'
---

**Status:** active. **Where:** [host-mounted modules pattern](../patterns/host-mounted-modules.md),
every doc under [modules](../modules/index.md), [hosts](../hosts/index.md).

## Context

Every darwin feature module declared `options.kriswill.<feature>.enable` and
gated its config behind `lib.mkIf`; `core.nix` fan-outed `mkDefault true` for
~18 of them and hosts blanket-imported everything, then toggled. The gating was
pure double bookkeeping: every gate evaluated to `true` on every importing
host, so the flags selected nothing. Meanwhile the `nebula-snowglobe` branch
(NixOS desktop, disjoint git history) had already settled on ungated deferred
modules in `flake.modules.nixos.*` plus first-class dendritic host files under
`modules/hosts/nebula/` — and the two branches are meant to merge into one
repo later.

## Decision

A module mounted into a host is active, period:

- Universal features became plain deferred modules in
  `flake.modules.darwin.<name>` (options + `mkIf` deleted; the `core.nix`
  fan-out and master `kriswill.enable` removed).
- Host-selective features moved to `modules/hosts/` files merging straight
  into `configurations.darwin.<host>.module` — deferredModule definitions
  merge, so one file mounts podman-desktop/apple-container/codebase-memory-mcp
  into k + SOC; `modules/hosts/k/claude-account-selector/` and
  `modules/hosts/SOC-Kris-Williams/alias-en0.nix` are single-host.
  claude-account-selector's option set was hardcoded into its `let` block
  (single consumer).
- `modules/lib.nix` (`kriswill.lib`) died with the namespace: the
  [darwin](../modules/darwin.md) realiser extends `nixpkgs.lib` inline;
  `mkProgramOption` was deleted (nh, its only user, is a one-liner now),
  `lib/default.nix` keeps only `kanagawa`.
- The apple-container sub-flake kept its enable/package options (idiomatic
  standalone-flake API) but renamed `kriswill.apple-container.*` →
  `services.apple-container.*`; mount files set `enable = true`.
- `ssh.nix` and `neovide.nix` were deleted outright — both were toggle-only
  stubs with empty config bodies. ssh's client config (ForwardAgent, the
  1Password agent socket, the `~/.ssh/config.d/*` include) lives entirely in
  the stow tree (`home/ssh/`, macOS's own `/usr/bin/ssh`, nothing to install);
  neovide is a per-host user package in `modules/hosts/*.nix` and needs no
  `NEOVIDE_NEOVIM_BIN` since nvim and its tools are on the global PATH.

Class dirs stay (`modules/darwin/` here, `modules/nixos/` on nebula) so a
merge drops the trees side by side with zero path collisions.

## Consequences

- Adding a universal feature is still just dropping a file; per-host wiring is
  now visible in file placement instead of option flips, and mini/k/SOC host
  files shrink to imports + package list + platform/overlays.
- Verified behavior-preserving: `nix store diff-closures` pre→post is empty
  for all three hosts; the only launchd delta is the intentional
  `services.apple-container` rename inside an error string.
- Watch out: a new `modules/hosts/*.nix` file must be `git add`ed before
  `nix build` (untracked files are invisible to import-tree, so a feature
  silently vanishes); `okf scaffold` classifies `modules/hosts/` files as
  host vs feature-mount by whether the basename matches the
  `configurations.darwin.<name>` they define.

## Citations

- Commits `ea9ae21`, `2b32779`, `ef3cd77`, `0e30f71`, `76b1b70`
- Inspiration: `nebula-snowglobe` branch (`modules/nixos/*`, `modules/hosts/nebula/*`)
