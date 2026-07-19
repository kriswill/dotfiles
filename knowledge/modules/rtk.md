---
type: Dual Module
title: Rtk
description: 'rtk — CLI proxy that filters dev command output (git, grep, cargo, npm, docker, aws, …) before it reaches an LLM''s context.'
resource: modules/darwin/rtk.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-19T00:06:40+00:00'
---

[rtk](https://github.com/rtk-ai/rtk) (Rust Token Killer) is a single-binary
CLI proxy that rewrites 100+ common dev commands (git, grep, cargo, npm,
docker, aws, …) to filtered/compacted output before it reaches an LLM's
context, claiming 60-90% token savings. Here it's just installed onto
`environment.systemPackages`; the [rtk package](../packages/rtk.md) does the
build.

Mounted ungated on every host of both classes
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).
A cross-OS twin — parallel implementations in each class dir (see the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md)).

Installing the package alone does nothing for a shell — rtk only rewrites
commands once its hook is registered in the calling tool. For Claude Code
that's a one-time per-user `rtk init -g`, which patches
`~/.claude/settings.json` with a `PreToolUse`/`Bash` hook running
`rtk hook claude` and drops `~/.claude/RTK.md` (referenced from
`~/.claude/CLAUDE.md` via `@RTK.md`) documenting the meta commands
(`rtk gain`, `rtk discover`, `rtk proxy <cmd>`). None of that hook wiring is
Nix-managed — it lives in the user's `~/.claude/` config, outside this repo.

## Source

- darwin module: [`modules/darwin/rtk.nix`](../../modules/darwin/rtk.nix)
- NixOS module: [`modules/nixos/rtk.nix`](../../modules/nixos/rtk.nix)

## Citations

- [rtk repository & README](https://github.com/rtk-ai/rtk)
- [rtk project site](https://www.rtk-ai.app)
