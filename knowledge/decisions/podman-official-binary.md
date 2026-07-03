---
type: Decision
title: Podman From the Official Binary, Self-contained
description: podman is packaged as a fixed-output derivation of the official darwin_arm64 release (nixpkgs' derivation is linux-only) with vfkit + gvproxy bundled into its own libexec.
resource: pkgs/podman.nix
tags: [podman, containers, packaging]
timestamp: '2026-07-03T12:00:00-07:00'
---

**Status:** active. **Where:** [podman](../packages/podman.md),
[podman-desktop](../modules/podman-desktop.md).

## Context

nixpkgs' podman derivation sets `meta.platforms = lib.platforms.linux`, so it
refuses to evaluate on aarch64-darwin and broke every rebuild that pulled it
into a profile. Overriding the meta would still build a derivation upstream
doesn't support on darwin.

## Decision

- `pkgs/podman.nix` fetches the official
  `podman-remote-release-darwin_arm64.zip` as a fixed-output derivation and
  installs the adhoc-signed Mach-O binaries verbatim (`dontFixup` keeps the
  signature valid); the overlay replaces `pkgs.podman` so host package lists
  need no changes (`07684b6`).
- The upstream zip is the remote client only, so the machine helpers podman
  needs are bundled in: vfkit + gvproxy are installed into
  `$out/libexec/podman`, which podman's compiled-in darwin default
  `helper_binaries_dir` finds via `$BINDIR/../libexec/podman` (`f3fb252`).
  This replaced a `containers.conf` override that hardcoded a per-user
  profile path.
- `/libexec` is added to `environment.pathsToLink` (gated on
  `podman-desktop.enable`) because `os.Executable` is not symlink-resolved on
  darwin — invoked via the profile symlink, `$BINDIR` is the profile `bin`,
  so the profile must expose `libexec/podman` too.

**Amended 2026-07-03:** the overlay is now internally platform-guarded
([`overlays/podman.nix`](../../overlays/podman.nix):
`if prev.stdenv.isDarwin then … else prev.podman`) because every host on both
OSes applies the whole overlay set — Linux keeps nixpkgs' podman.

## Consequences

- podman is self-contained: no standalone vfkit/gvproxy host packages, no
  helper-dir override in `containers.conf`.
- Version bumps mean updating `version` + hash in `pkgs/podman.nix` (FOD).
- nixpkgs' krunkit/libkrun stack is gone; networking helpers are the bundled
  ones.

## Citations

- Commits `07684b6`, `4dc74e4`, `f3fb252`
