---
type: Decision
title: Apple container — Repackage and Wrap, Don't Build
description: Apple's container CLI is repackaged from the signed .pkg (never built from source) and wrapped so its install root resolves to the store path where the plugins actually live.
resource: flakes/apple-container/README.md
tags: [containers, packaging, code-signing]
timestamp: '2026-07-02T00:00:00-07:00'
---

**Status:** active. **Where:** [apple-container](../packages/apple-container.md)
sub-flake.

## Context

Apple's `container` needs the macOS SDK, Virtualization entitlements, and
re-signing to build from Swift source — none of which fit a Nix build. Apple
ships a flat, signed installer `.pkg`. Separately, `container` locates its
plugins under `<install-root>/libexec/container/plugins`, where install-root
is the grandparent of its executable path via `_NSGetExecutablePath` — **not
symlink-resolved** — so invoked through a Nix profile symlink it resolves to
the profile (which links `bin/` but not `libexec/`) and fails with
`cannot find any plugins`.

## Decision

- Extract the signed release `.pkg` (`xar` + `cpio`) and install the Mach-O
  binaries verbatim; `dontFixup = true` preserves Apple's signature and
  entitlements.
- `makeWrapper` the CLI to exec from `$out`, fixing the install root to the
  read-only store path (correct: all mutable state lives under
  `CONTAINER_APP_ROOT`).
- The darwin module adds two activation guards: refuse to activate over a
  foreign (`.pkg`/Homebrew) install, and detect launchd runtime drift after a
  version bump (stop the old apiserver, remind to `container system start`).

## Consequences

- Ships CLI only; the runtime is managed by Apple's own launchd tooling.
- After each bump the apiserver must be re-pointed
  (`container system stop && container system start`).

## Citations

- [Sub-flake README](../../flakes/apple-container/README.md)
- [apple/container InstallRoot.swift](https://github.com/apple/container)
