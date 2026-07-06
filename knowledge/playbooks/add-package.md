---
type: Playbook
title: Add a Custom Package
description: Add a package under pkgs/ (or as a sub-flake), expose it via perSystem.packages and an overlay, and handle unfree licensing.
tags: [nix, packaging]
timestamp: '2026-07-03T12:00:00-07:00'
---

## Examples

1. Create `pkgs/<name>.nix` (or `pkgs/<name>/package.nix`).
2. Register it in [packages](../modules/packages.md):
   `<name> = pkgs.callPackage ../pkgs/<name>.nix { };` — under the right
   platform guard (`lib.optionalAttrs`) if it only builds on one OS.
3. To put it on `pkgs` for hosts: add `overlays/<name>.nix` and register it in
   [overlays](../modules/overlays.md).
4. If unfree: add an `allowUnfreePredicate` entry in `modules/darwin/core.nix`
   (darwin policy only — nebula's unfree policy comes via snowglobe-lib
   profiles); see [unfree deny-by-default](../decisions/unfree-default-deny.md).
5. `git add` everything, then `nix build .#packages.<system>.<name>`
   (aarch64-darwin or x86_64-linux).

For a package that deserves its own flake (forked source,
standalone-buildable, future separate repo), use the
[sub-flake extraction pattern](../patterns/subflake-extraction.md) instead —
the `derivation-to-flake` skill automates it.

Afterwards: `okf scaffold && okf index` to add the catalog doc here
(dev-shell PATH; outside it, `nix run .#okf -- <cmd>`).
