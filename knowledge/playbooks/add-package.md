---
type: Playbook
title: Add a Custom Package
description: Add a package under pkgs/ (or as a sub-flake), expose it via perSystem.packages and an overlay, and handle unfree licensing.
tags: [nix, packaging]
timestamp: '2026-07-02T00:00:00-07:00'
---

## Examples

1. Create `pkgs/<name>.nix` (or `pkgs/<name>/package.nix`).
2. Register it in [packages](../modules/packages.md):
   `<name> = pkgs.callPackage ../pkgs/<name>.nix { };`
3. To put it on `pkgs` for hosts: add `overlays/<name>.nix` and register it in
   [overlays](../modules/overlays.md).
4. If unfree: add an `allowUnfreePredicate` entry in core.nix — see
   [unfree deny-by-default](../decisions/unfree-default-deny.md).
5. `git add` everything, then `nix build .#packages.aarch64-darwin.<name>`.

For a package that deserves its own flake (forked source,
standalone-buildable, future separate repo), use the
[sub-flake extraction pattern](../patterns/subflake-extraction.md) instead —
the `derivation-to-flake` skill automates it.

Afterwards: `bun scripts/okf/okf.ts scaffold && bun scripts/okf/okf.ts index`
to add the catalog doc here.
