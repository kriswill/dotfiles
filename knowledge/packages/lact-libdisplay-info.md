---
type: Overlay
title: Lact Libdisplay Info
description: TEMPORARY overlay building lact against libdisplay-info 0.3.0 — works around nixpkgs' libdisplay-info 0.4.0 bump, which breaks lact 0.9.1's vendored libdisplay-info-sys pkg-config probe.
resource: overlays/lact-libdisplay-info.nix
tags: [overlay, nixos, temporary]
timestamp: '2026-07-29T05:36:01+00:00'
---

nixpkgs bumped `libdisplay-info` 0.3.0 → 0.4.0 (`3927e90c`, 2026-07-25).
lact 0.9.1 vendors `libdisplay-info-sys` 0.3.0, whose `build.rs` probes
pkg-config for `libdisplay-info >= 0.1.0, < 0.4.0` and `unwrap()`s — so the
build panics and every [nebula](../hosts/nebula.md) rebuild dies (lact is
enabled by snowglobe-lib's AMD GPU module).

Upstream's fix switches lact's `buildInputs` to a new `libdisplay-info_0_3`
attr (master `3ee083c2`, 2026-07-27). Neither that attr nor the generic-ised
derivation behind it (`f73b4037`) exists in our nixos-unstable rev (`624af66`,
the channel HEAD as of 2026-07-28) — it carries only `libdisplay-info` 0.4.0
and `libdisplay-info_0_2`. So the overlay reproduces upstream's 0.3.0 itself:
`libdisplay-info.overrideAttrs` with the version and hash lifted verbatim from
upstream's `pkgs/by-name/li/libdisplay-info/0.3.nix`, injected into lact via
`override`. (0.2.0 would also satisfy the crate's `>= 0.1.0, < 0.4.0` range —
it bindgens against whatever headers are installed — but matching upstream
means the eventual flake.lock bump changes nothing.) Inert on darwin
(`lib.optionalAttrs isLinux` → empty set).

**DELETE this overlay** (and its line in
[`modules/overlays.nix`](../../modules/overlays.nix)) at the first flake.lock
bump that carries `3ee083c2`.

## Citations

- [lact: pin libdisplay-info_0_3 `3ee083c2`](https://github.com/NixOS/nixpkgs/commit/3ee083c2) — upstream fix
- [libdisplay-info: 0.3.0 -> 0.4.0 `3927e90c`](https://github.com/NixOS/nixpkgs/commit/3927e90c) — the breaking bump

## Source

- Overlay: [`overlays/lact-libdisplay-info.nix`](../../overlays/lact-libdisplay-info.nix)
