---
type: Playbook
title: Add a Darwin Feature Module
description: Create and mount a new nix-darwin feature module — universal or host-selective; registration is automatic.
tags: [nix, module]
timestamp: '2026-07-03T00:00:00-07:00'
---

## Examples

1. Decide where it mounts, per the
   [host-mounted modules pattern](../patterns/host-mounted-modules.md):
   - **Every host** → `modules/darwin/<name>.nix` defining
     `flake.modules.darwin.<name>` ([tmux](../modules/tmux.md) is the
     reference); hosts blanket-import the whole set.
   - **Some hosts** → `modules/hosts/<name>.nix` mounting a shared module into
     each `configurations.darwin.<host>.module`
     ([podman-desktop](../modules/podman-desktop.md)).
   - **One host** → `modules/hosts/<host>/<name>.nix` (or a directory when
     bundling adjacent files, like
     [claude-account-selector](../modules/claude-account-selector.md)).
2. No enable option, no `lib.mkIf` gate — being mounted is what turns it on.
3. No import wiring — discovery is automatic per the
   [Dendritic module layout](../patterns/dendritic-modules.md). Prefix a path
   component with `_` to exclude it.
4. **`git add` the file** — flakes only see tracked files.
5. Verify: `nix flake check`, then build or switch per
   [rebuild-and-rollback](rebuild-and-rollback.md).

Afterwards: run `bun scripts/okf/okf.ts scaffold` to stub the module's
catalog doc in this bundle, and `bun scripts/okf/okf.ts index` to list it.
