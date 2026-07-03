---
type: Playbook
title: Add a Darwin Feature Module
description: Create a new nix-darwin feature module — universal (ungated) or host-selective (behind a programs./services. enable); registration is automatic.
tags: [nix, module]
timestamp: '2026-07-03T00:00:00-07:00'
---

## Examples

1. Create `modules/darwin/<name>.nix` defining `flake.modules.darwin.<name>` —
   a bare file; a directory only when bundling adjacent config files. Pick the
   tier per the [host-mounted modules pattern](../patterns/host-mounted-modules.md):
   - **Universal** (every host): no options, no `lib.mkIf`
     ([tmux](../modules/tmux.md) is the reference).
   - **Host-selective**: gate behind `programs.<name>.enable` /
     `services.<name>.enable` ([podman-desktop](../modules/podman-desktop.md))
     and flip it in each wanting host's `modules/hosts/<hostname>/default.nix`.
   - **One machine only** (fixed IPs, hardware quirks): skip `modules/darwin/`;
     add a file beside that host's `default.nix` merging into
     `configurations.darwin.<hostname>.module`
     ([alias-en0](../modules/alias-en0.md)).
2. No import wiring — discovery is automatic per the
   [Dendritic module layout](../patterns/dendritic-modules.md). Prefix a path
   component with `_` to exclude it.
3. **`git add` the file** — flakes only see tracked files.
4. Verify: `nix flake check`, then build or switch per
   [rebuild-and-rollback](rebuild-and-rollback.md).

Afterwards: run `bun scripts/okf/okf.ts scaffold` to stub the module's
catalog doc in this bundle, and `bun scripts/okf/okf.ts index` to list it.
