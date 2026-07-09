---
type: Nix Package
title: Nas Mount
description: 'Mounts the UNAS Pro 4 Personal-Drive SMB share if not already mounted — a compiled Mach-O binary (pure-std Rust, no crates, bare rustc build) so rcodesign can sign it. Consumed by modules/darwin/nas-mount.nix.'
resource: pkgs/nas-mount/package.nix
tags: [package, darwin-only, rust, codesigning]
timestamp: '2026-07-09T20:09:02+00:00'
---

Mounts the UNAS Pro 4 Personal-Drive SMB share if not already mounted.
Deliberately a compiled Mach-O binary rather than a shell script — see
[nas-mount-codesigning](../decisions/nas-mount-codesigning.md): `rcodesign`
(the codesigning tool `scripts/sign-launchd-agents.ts` uses) only recognizes
Mach-O/bundle/DMG/pkg, not plain scripts. `main.rs` is pure `std`, no crates,
built via a bare `rustc -O` inside a plain `stdenv.mkDerivation` rather than
`rustPlatform.buildRustPackage`'s Cargo.lock machinery — there's nothing to
vendor. Takes `<mount-point> <smb-share>` as CLI args (passed via launchd's
`ProgramArguments` in the consuming module) rather than baking them in.

darwin-only (`meta.platforms`); registered in `modules/packages.nix` under
the `aarch64-darwin` guard alongside `kitten`/`podman`.

## Source

- Package: [`pkgs/nas-mount/package.nix`](../../pkgs/nas-mount/package.nix)
  + [`main.rs`](../../pkgs/nas-mount/main.rs)
- Overlay: [`overlays/nas-mount.nix`](../../overlays/nas-mount.nix) — exposes `pkgs.nas-mount`
- Consumer: [nas-mount module](../modules/nas-mount.md)
