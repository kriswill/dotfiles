---
type: Decision
title: Replace Lix With Determinate Nix
description: nebula's Nix moved from Lix to Determinate Nix because Lix lacks Nix ≥2.26 relative-path input locking, which made the ./flakes/* sub-flake inputs churn flake.lock on every rebuild.
tags: [nix, flakes, sub-flakes]
timestamp: '2026-07-03T21:45:00-07:00'
---

**Status:** active. **Where:** [determinate](../modules/determinate.md); only
nebula — the Macs were already on Determinate (installer-managed,
`nix.enable = mkForce false` in [core](../modules/core.md)).

## Context

The [sub-flake extraction pattern](../patterns/subflake-extraction.md) uses
relative-path inputs (`./flakes/ccglass`, `./flakes/apple-container`). Under
Lix these lock as machine-local `/nix/store/...-source/flakes/...` paths that
change with every tree edit, so every `nrs` (and every direnv reload) rewrote
`flake.lock` — twice per rebuild, differently per machine. Upstream Nix fixed
this in 2.26 (relative locking with a `parent` field,
[NixOS/nix#10089](https://github.com/NixOS/nix/pull/10089)); the Lix issue
tracking adoption ([lix#641](https://git.lix.systems/lix-project/lix/issues/641))
is open with Lix's Flakes feature set frozen for plugin extraction, so it
will not be fixed there.

## Decision

Swap the Nix implementation, not the pattern, and keep snowglobe-lib
unforked: snowglobe sets `nix.package = slib.setDefault pkgs.lix` at priority
1337 (deliberately weaker than `mkDefault`), so the determinate flake's NixOS
module — a plain priority-100 `nix.package` assignment — simply wins.
`modules/nixos/determinate.nix` imports `inputs.determinate.nixosModules.default`
and declares the install.determinate.systems substituter + FlakeHub cache key;
the first switch passed them as `--option` flags (chicken-and-egg: the
declarative settings aren't live until after the switch). Determinate's module
retargets the NixOS-generated nix.conf to `/etc/nix/nix.custom.conf`, included
by the determinate-nixd-managed `/etc/nix/nix.conf`, so snowglobe's
`nix.settings` all survive. The determinate input deliberately has no nixpkgs
`follows` (upstream recommends against it — FlakeHub cache misses), and the
module pins `nix.registry.nixpkgs` back to this flake's nixpkgs to override
determinate's nixpkgs-weekly registry default.

## Consequences

- `flake.lock`'s sub-flake nodes are now stable relative paths
  (`"path": "./flakes/ccglass"` + `"parent": []`) — no store paths, no
  narHash, no churn on dirty-tree rebuilds; verified by editing a tracked
  file and re-evaluating.
- Lazy trees (`lazy-trees = true`, default in Determinate ≥3.5) stop the
  whole repo being copied to the store on every eval.
- The lock format now requires Nix ≥2.26 on every consumer: fine for the
  Determinate-managed Macs, but a rollback to the Lix generation also needs
  the pre-swap `flake.lock`.
- Determinate Nix 3.21.1 reports upstream base 2.34.7; `nrs`/`nh os switch`
  work unchanged.

## Citations

- Commits `622efbc`
