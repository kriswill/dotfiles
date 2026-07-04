---
type: NixOS Module
title: Determinate
description: 'Determinate Nix replaces snowglobe-lib''s Lix default: snowglobe sets nix.package at priority 1337 (setDefault); the determinate module''s plain assignment wins — no fork, no mkForce.'
resource: modules/nixos/determinate.nix
tags: [nixos-module]
timestamp: '2026-07-03T21:31:10-07:00'
---

Determinate Nix replaces snowglobe-lib's Lix default: snowglobe sets nix.package at priority 1337 (setDefault); the determinate module's plain assignment wins — no fork, no mkForce. Its determinate-nixd owns /etc/nix/nix.conf and includes the NixOS-generated settings via /etc/nix/nix.custom.conf, so snowglobe's nix.settings survive. Why we left Lix: no Nix ≥2.26 relative-path input locking (lix#641), which made the ./flakes/* sub-flake inputs churn flake.lock on every rebuild.

Universal within the nixos class (always-on: the imported determinate module's
`determinate.enable` defaults to true); imports the `determinate` flake input's
`nixosModules.default` and adds the install.determinate.systems substituter +
FlakeHub cache key declaratively, plus a `nix.registry.nixpkgs.flake` pin to
this flake's own nixpkgs (otherwise determinate pins the registry to FlakeHub's
nixpkgs-weekly). Auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md). Rationale:
[Replace Lix With Determinate Nix](../decisions/lix-to-determinate.md).

## Source

- Module: [`modules/nixos/determinate.nix`](../../modules/nixos/determinate.nix)
