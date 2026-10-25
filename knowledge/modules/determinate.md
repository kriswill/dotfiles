---
type: NixOS Module
title: Determinate
description: 'Determinate Nix replaces snowglobe-factory''s Lix default: snowglobe sets nix.package at priority 1337 (setDefault); the determinate module''s plain assignment wins — no fork, no mkForce.'
resource: modules/nixos/determinate.nix
tags: [nixos-module]
generated: { by: okflight/0.4.0, at: 2026-07-03T21:31:10-07:00 }
---

Determinate Nix replaces snowglobe-factory's Lix default: snowglobe sets nix.package at priority 1337 (setDefault); the determinate module's plain assignment wins — no fork, no mkForce. Its determinate-nixd owns /etc/nix/nix.conf and includes the NixOS-generated settings via /etc/nix/nix.custom.conf, so snowglobe's nix.settings survive. Why we left Lix: no Nix ≥2.26 relative-path input locking (lix#641), which made the ./flakes/* sub-flake inputs churn flake.lock on every rebuild.

Universal within the nixos class (always-on: the imported determinate module's
`determinate.enable` defaults to true); imports the `determinate` flake input's
`nixosModules.default` and adds the install.determinate.systems substituter +
FlakeHub cache key declaratively, plus a `nix.registry.nixpkgs.flake` pin to
this flake's own nixpkgs (otherwise determinate pins the registry to FlakeHub's
nixpkgs-weekly). It also sets `narinfo-cache-negative-ttl = 300` (default
3600). Without it, an `nrs` run before CI has pushed nebula's toplevel to
FlakeHub Cache leaves the misses cached, and later runs keep building
locally for up to an hour after the paths arrive. The daemon does the
lookups and `k` is not trusted, so it can't be overridden per command. This
is nebula only; the Macs' Determinate Nix is not managed by nix-darwin.
Measured 2026-10-24 against a throwaway HTTP cache on localhost. A path
published 2 s after a recorded miss was found at t=303 s with 300. With the
old 3600 it was still missing at t=343 s. No HTTP request was made while the
miss was cached.
Auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md). Rationale:
[Replace Lix With Determinate Nix](../decisions/lix-to-determinate.md).

## Source

- Module: [`modules/nixos/determinate.nix`](../../modules/nixos/determinate.nix)
