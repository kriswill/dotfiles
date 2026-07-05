---
type: Sub-flake
title: ccglass
description: ccglass — local logging reverse-proxy + web dashboard for coding agents, built as a standalone binary.
resource: flakes/ccglass/
tags: [sub-flake, package]
timestamp: '2026-07-04T00:00:00-07:00'
---

ccglass — local logging reverse-proxy + web dashboard for coding agents, built as a standalone binary.

Consumed by the root flake as a relative-path input — see the
[sub-flake extraction pattern](../patterns/subflake-extraction.md). The
binary is produced by `bun build --compile` (see the
[Bun runtime](../bun-runtime.md)) from a patched upstream checkout; version
bumps and the bun-compile hazards to scan for are covered by the
[bump-ccglass playbook](../playbooks/bump-ccglass.md).

## Source

- Flake: [`flakes/ccglass/`](../../flakes/ccglass/)
- README: [`flakes/ccglass/README.md`](../../flakes/ccglass/README.md)
