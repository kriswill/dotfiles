---
type: Overlay
title: Ld64 Lld
description: 'TEMPORARY overlay linking kitty/vfkit/starship with LLVM lld on darwin — works around the pinned nixpkgs'' cctools ld64 1010.6 SIGTRAP until the staging fix reaches nixos-unstable.'
resource: overlays/ld64-lld.nix
tags: [overlay, darwin, temporary]
generated: { by: okflight/0.4.0, at: 2026-07-11T13:15:00-07:00 }
sources:
  - id: nixos-nixpkgs-536365
    resource: https://github.com/NixOS/nixpkgs/pull/536365
    title: NixOS/nixpkgs#536365
  - id: kitty-workaround-83cc719d53
    resource: https://github.com/NixOS/nixpkgs/commit/83cc719d53
    title: kitty workaround `83cc719d53`
  - id: vfkit-workaround-559ebc0633
    resource: https://github.com/NixOS/nixpkgs/commit/559ebc0633
    title: vfkit workaround `559ebc0633`
  - id: starship-workaround-883e799eb2
    resource: https://github.com/NixOS/nixpkgs/commit/883e799eb2
    title: starship workaround `883e799eb2`
---

The pinned nixpkgs' cctools ld64 1010.6 crashes (SIGTRAP, "Trace/BPT trap:
5") linking certain aarch64-darwin binaries — kitty 0.47.4 (`glfw-cocoa.so`),
vfkit 0.6.3 (cgo external link), starship 1.26.0 (rustc link) — so hydra has
no cache entries and every darwin rebuild dies. The root fix is on staging
([NixOS/nixpkgs#536365](https://github.com/NixOS/nixpkgs/pull/536365));
master carries per-package `-fuse-ld=lld` workarounds (kitty `83cc719d53`,
vfkit `559ebc0633`, starship `883e799eb2`, all 2026-07-09/10) that had not
reached nixos-unstable as of 2026-07-11 (HEAD `0bb7ec5`).

This overlay replicates each master workaround **byte-identically** (same
`nativeBuildInputs` append position, same `NIX_CFLAGS_LINK` value), so the
resulting drvs hash-match hydra's `nixpkgs/unstable` builds and are *fetched
from cache* rather than compiled. Inert on Linux (`lib.optionalAttrs
isDarwin` → empty set; [nebula](../hosts/nebula.md) cross-eval verified).

**DELETE this overlay** (and its line in
[`modules/overlays.nix`](../../modules/overlays.nix)) at the first
flake.lock bump where all three packages build without it. vfkit reaches the
darwin hosts through [podman](podman.md)'s bundled machine helpers.

## Source

- Overlay: [`overlays/ld64-lld.nix`](../../overlays/ld64-lld.nix)
