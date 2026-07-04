---
type: Pattern
title: Sub-flake Extraction
description: Packages destined for standalone life live under flakes/<name>/ as self-contained flakes consumed via relative-path inputs — extraction to a separate repo is a one-line URL swap.
resource: flakes/
tags: [flake, packaging, modularity]
timestamp: '2026-07-02T00:00:00-07:00'
---

A package that warrants its own flake — forked or patched source,
standalone-buildable, or headed for its own repo — lives under
`flakes/<name>/` instead of `pkgs/`:

1. `flakes/<name>/flake.nix` uses flake-parts and exposes
   `packages.<system>.<name>` (+ `default`). Sub-flake files must be
   **git-tracked** to be visible.
2. The root flake consumes it as a relative-path input
   (`inputs.<name>.url = "./flakes/<name>"`) with
   `inputs.<name>.inputs.{nixpkgs,flake-parts}.follows` to dedupe.
3. [packages](../modules/packages.md) re-exports it under
   `perSystem.packages`; if a host needs it on `pkgs`, an inline overlay in
   [overlays](../modules/overlays.md) bridges it.

Extraction to a separate repo later is just swapping the input URL
`"./flakes/<name>"` → `"github:owner/<name>"` — nothing else moves.

Relative-path inputs need Nix ≥2.26 to lock stably (a relative `path` node
with a `parent` field); under Lix they re-locked to machine-local store paths
on every tree edit, churning `flake.lock` — the reason nebula moved to
Determinate Nix ([Replace Lix With Determinate Nix](../decisions/lix-to-determinate.md)).

Worked examples: [ccglass](../packages/ccglass.md) and
[apple-container](../packages/apple-container.md) (which also exports a
darwin module). Simple packages stay in `pkgs/` per the
[add-package playbook](../playbooks/add-package.md). The
`derivation-to-flake` skill (`.claude/skills/derivation-to-flake/`) automates
the whole extraction end to end.
