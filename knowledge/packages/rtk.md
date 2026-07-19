---
type: Nix Package
title: Rtk
description: CLI proxy that filters dev command output to cut LLM token usage.
resource: pkgs/rtk.nix
tags: [package]
timestamp: '2026-07-19T00:06:40+00:00'
---

`rustPlatform.buildRustPackage` for upstream
[rtk-ai/rtk](https://github.com/rtk-ai/rtk), pinned by tag via
`fetchFromGitHub` rather than a flake input (all dependencies come from
crates.io, so `cargoLock.lockFile` reads the crate's own committed
`Cargo.lock` directly — no vendoring hash to maintain, no reason to add a
flake input for a source that isn't forked or patched). `doCheck = false`:
the crate's integration tests shell out to git/docker/aws/etc. and expect a
live, tool-populated environment the sandbox doesn't provide.

Consumed by the [rtk module twins](../modules/rtk.md), which install it onto
`environment.systemPackages`.

Added per the [add-package playbook](../playbooks/add-package.md).

## Source

- Package: [`pkgs/rtk.nix`](../../pkgs/rtk.nix)
- Version at last scaffold: `0.43.0`
- Overlay: [`overlays/rtk.nix`](../../overlays/rtk.nix) — exposes/replaces `pkgs.rtk`

## Citations

- [rtk repository & README](https://github.com/rtk-ai/rtk)
