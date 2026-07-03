---
type: Playbook
title: Bump ccglass
description: Update the ccglass sub-flake for a new upstream release via the patch-ccglass skill.
tags: [ccglass, maintenance]
timestamp: '2026-07-02T00:00:00-07:00'
---

[ccglass](../packages/ccglass.md) tracks an upstream that needs a fork patch
to survive bun compilation, so bumps are driven by the **`patch-ccglass`
skill** (`.claude/skills/patch-ccglass/`) rather than by hand:

## Examples

1. Invoke the skill (in Claude Code: `/patch-ccglass`, or ask to "bump
   ccglass").
2. It clones the latest upstream tag, scans the source for bun-compile
   hazards, regenerates and tests the fork patch, then builds the sub-flake.
3. Verification covers all three surfaces: the compiled binary, the MCP
   server, and the web dashboard, on aarch64-darwin.
4. Commit; the root flake follows the sub-flake via its relative-path input
   (see [sub-flake extraction](../patterns/subflake-extraction.md)) — a
   `nix flake update ccglass` refreshes the lock if needed.
