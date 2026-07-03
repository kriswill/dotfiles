---
type: Decision
title: Remove Option Gating; Mount Modules Into Hosts
description: Dropped the kriswill.* namespace and its core.nix mkDefault fan-out — universal modules are ungated, host-selective ones gate on idiomatic programs./services. enables flipped per host, and hosts became modules/hosts/<hostname>/ folders mirroring the nebula-snowglobe layout.
tags: [nix, module, architecture]
timestamp: '2026-07-03T12:00:00-07:00'
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
modules plus per-host dendritic files — and the two branches are meant to
merge into one repo later, so the layouts should line up.

## Decision

Feature selection is expressed at the host; the personal option namespace and
the fan-out of defaults are gone:

- **Universal features** (every darwin host) became plain ungated deferred
  modules in `flake.modules.darwin.<name>` — options and `mkIf` deleted, the
  `core.nix` fan-out and master `kriswill.enable` removed. The blanket
  `builtins.attrValues config.flake.modules.darwin` import turns them on.
- **Host-selective features** stay in `modules/darwin/` but gate on a single
  idiomatic enable — `programs.<name>.*` for user-facing programs
  (podman-desktop, claude-account-selector, whose
  defaultProfile/profiles/rules/desktopProfile options survived the namespace
  move), `services.<name>.*` for daemons re-exported from sub-flakes
  (apple-container, codebase-memory-mcp) — flipped in the wanting host's
  `default.nix`. An earlier iteration mounted these as naked files under
  `modules/hosts/` merging into `configurations.darwin.<host>.module`; that
  was rejected in review — modules belong under `modules/darwin/`, and
  `modules/hosts/` holds hosts.
- **Hosts are folders**: `modules/hosts/<hostname>/default.nix` (exact
  hostname; darwin now, nixos after the merge), with truly host-specific
  files beside it (`SOC-Kris-Williams/alias-en0.nix` — a fixed dev IP that
  belongs to that machine, not to the shared module set).
- `modules/lib.nix` (`kriswill.lib`) died with the namespace: the
  [darwin](../modules/darwin.md) realiser extends `nixpkgs.lib` inline;
  `mkProgramOption` was deleted (nh, its only user, is a one-liner now),
  `lib/default.nix` keeps only `kanagawa`.
- The apple-container sub-flake kept its enable/package options (idiomatic
  standalone-flake API, darwin-only module) renamed
  `kriswill.apple-container.*` → `services.apple-container.*`.
- `ssh.nix` and `neovide.nix` were deleted outright — both were toggle-only
  stubs with empty config bodies. ssh's client config (ForwardAgent, the
  1Password agent socket, the `~/.ssh/config.d/*` include) lives entirely in
  the stow tree (`home/ssh/`, macOS's own `/usr/bin/ssh`, nothing to install);
  neovide is a per-host user package in `modules/hosts/*/default.nix` and
  needs no `NEOVIDE_NEOVIM_BIN` since nvim and its tools are on the global
  PATH.

Class dirs stay (`modules/darwin/` here, `modules/nixos/` on nebula) so a
merge drops the trees side by side with zero path collisions.

**Amended 2026-07-03:** the merge landed — `modules/nixos/` is in-tree; nebula
registers as `modules/hosts/nebula.nix` (flat registry entry through
snowglobe-lib's `mkNixosHost`) plus a `nebula/` folder of host files, the
shape `okf scaffold` already recognizes.

## Consequences

- Adding a universal feature is still just dropping a file; host-selective
  wiring is one enable line in the wanting host's `default.nix`, and host
  folders stay basic (imports + package list + enables + platform/overlays).
- Verified behavior-preserving at the first pass: `nix store diff-closures`
  pre→post was empty for all three hosts; the only launchd delta was the
  intentional `services.apple-container` rename inside an error string. The
  gated-options revision re-verified against the same baseline.
- Overriding a universal module's setting from a host: override-prone scalars
  (dnsmasq, homebrew, macos-defaults, neovim env vars, oksh, zsh history)
  kept `lib.mkDefault`, so a plain host assignment wins; everything else sits
  at normal module priority and needs `lib.mkForce` from the host.
- direnv-nom's `diff` enum (nvd/native/none) survived the namespace move as
  `programs.direnv-nom.diff` — a behavior setting on a universal module, not
  a gate (an xhigh review caught its accidental removal).
- Watch out: a new module file must be `git add`ed before `nix build`
  (untracked files are invisible to import-tree, so a feature silently
  vanishes); `okf scaffold` understands the host-folder layout (flat
  `<host>.nix` also recognized for nebula compatibility) and stubs
  host-specific sibling files as darwin-module docs.

## Citations

- Commits `ea9ae21`, `2b32779`, `ef3cd77`, `0e30f71`, `76b1b70` (first pass),
  `6a25ce0` (gated-options + host-folders revision)
- Inspiration: `nebula-snowglobe` branch (`modules/nixos/*`, `modules/hosts/nebula/*`)
