---
type: Pattern
title: Host Registry Realisers
description: Hosts register into typed configurations.<class>.<hostname> option registries; per-class realiser modules (darwin.nix via darwinSystem, nixos.nix via snowglobe-lib's mkNixosHost) turn each entry into a flake output plus a per-host flake check.
resource: modules/nixos.nix
tags: [flake-parts, nix, architecture]
timestamp: '2026-07-03T12:00:00-07:00'
---

Hosts are not direct `darwinSystem`/`mkNixosHost` calls. Each registers into a
typed option registry — `configurations.darwin.<hostname>` or
`configurations.nixos.<hostname>` — and a per-class **realiser** module
([darwin](../modules/darwin.md), [nixos](../modules/nixos.md)) turns every
entry into a flake output. The two realisers are isomorphic in shape but use
different builders — a deliberate outcome of the
[dual-OS unification](../decisions/nixos-darwin-unification.md).

Mechanics:

- **Typed registries**: both are `lib.types.lazyAttrsOf` a submodule. The
  darwin registry carries just `module`; the nixos one adds snowglobe-lib's
  hardware metadata (`cpu-vendor`, `gpu-vendors`, `firmware`, `isVM`,
  `stateVersion`), so hardware wiring lives in the registry entry
  ([`modules/hosts/nebula.nix`](../../modules/hosts/nebula.nix)), not in
  feature modules.
- **`module` is a `lib.types.deferredModule`** — the load-bearing detail.
  Because deferred modules merge, each of nebula's side files
  (`modules/hosts/nebula/*.nix`) is a first-class flake-parts module merging
  into `configurations.nixos.nebula.module` with no hand-maintained imports
  list. This is the mechanism underlying the host-specific tier of
  [host-mounted modules](host-mounted-modules.md).
- **Realisation**: `mapAttrs` over the registry —
  [`modules/darwin.nix`](../../modules/darwin.nix) calls
  `inputs.darwin.lib.darwinSystem` with `nixpkgs.lib` extended by
  `lib/default.nix` (the kanagawa palette) injected as the evaluation's `lib`
  via `specialArgs`; [`modules/nixos.nix`](../../modules/nixos.nix) calls
  snowglobe-lib's `mkNixosHost`, manually injecting
  `specialArgs = { inherit inputs; }` (mkNixosHost doesn't) and **without**
  the extended lib — nixos modules import `lib/` files by path (the asymmetry
  noted in [cross-OS module twins](cross-os-module-twins.md)).
- **Per-host checks**: each realiser also emits a
  `configurations:<class>:<host>` entry into `flake.checks`, keyed by the
  host's platform — so `nix flake check` builds only the current system's
  hosts and eval-checks the rest. The full nebula cross-eval gate from a Mac
  is `nix eval .#nixosConfigurations.nebula.config.system.build.toplevel.drvPath`.
- **Registry-entry responsibilities**: the entry's `module` does the blanket
  class import (`imports = builtins.attrValues config.flake.modules.<class>`),
  re-applies `flake.overlays`, and absorbs builder quirks (`mkNixosHost` only
  sets `sops.defaultSopsFile` when given a `configDir`, so `nebula.nix` sets
  it explicitly). Non-`.nix` files (`secrets.yaml`, `*.pub`) sit safely in the
  host dir — import-tree only picks up `.nix` (see the
  [Dendritic layout](dendritic-modules.md)).

Tradeoffs: typed validation, uniform per-host checks, and colocated hardware
metadata, at the cost of one level of indirection over calling the builders
directly. The nixos side is coupled to snowglobe-lib — its profiles and
desktop machinery come for free, the extended-lib asymmetry is the price.

## Citations

- [`modules/darwin.nix`](../../modules/darwin.nix), [`modules/nixos.nix`](../../modules/nixos.nix), [`modules/hosts/nebula.nix`](../../modules/hosts/nebula.nix)
- Realisers kept separate at the dual-OS merge `76a05ff` (PR #22, `0b8a629`); darwin realiser adapted from the mightyiam/dendritic example
