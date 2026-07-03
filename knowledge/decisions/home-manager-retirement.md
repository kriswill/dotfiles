---
type: Decision
title: Home-manager Retirement
description: home-manager was removed entirely — every config is now a darwin module plus the stow tree, one evaluation model instead of two.
tags: [home-manager, architecture]
timestamp: '2026-07-03T12:00:00-07:00'
---

**Status:** done (2026). **Where:** repo-wide.

## Context

home-manager layered a second module system, second activation phase, and
second config namespace over nix-darwin for what is a single-user,
single-platform repo. Most HM modules were either thin wrappers around files
(better served by the [stow tree](../patterns/stow-tree.md)) or system-level
concerns (better served by darwin modules).

## Decision

Retire home-manager completely, in stages: port `core.nix` modules to darwin
modules + stow (`8498bfe`), move yazi (`982d119`), port the last two enabled
modules — [podman-desktop](../modules/podman-desktop.md) and
[claude-account-selector](../modules/claude-account-selector.md) — and delete
the disabled brave/firefox/vscode modules that depended on HM's `programs.*`
generators (`1f1c5ba`), then remove HM entirely (`a9d6501`).

Ports were verified byte-identical to the HM output before switching:
generated files were rebuilt with `writeText`, and HM's `launchd.agents`
became nix-darwin `launchd.user.agents`.

## Consequences

- One module system, one activation phase; `darwin-rebuild switch` is the
  only apply step.
- Plain configs are editable in-place via the stow tree without a rebuild.
- HM-generator-dependent modules (browser policies, vscode) are gone —
  recoverable from git history if ever wanted.

**Amended 2026-07-03:** since the
[dual-OS unification](nixos-darwin-unification.md), configs are per-class
system modules (darwin + nixos twins) plus the shared stow tree; the apply
step is `darwin-rebuild switch` on Macs and `nixos-rebuild switch` on nebula —
still exactly one module system per host, still no home-manager.

## Citations

- Commits `8498bfe`, `982d119`, `1f1c5ba`, `a9d6501`
