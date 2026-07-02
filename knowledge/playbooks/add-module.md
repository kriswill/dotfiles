---
type: Playbook
title: Add a Darwin Feature Module
description: Create, register (automatic), and enable a new nix-darwin feature module.
tags: [nix, module]
timestamp: '2026-07-02T00:00:00-07:00'
---

## Examples

1. Create `modules/darwin/<name>.nix` — a bare file; use a directory only when
   bundling adjacent config files. Follow the
   [module option pattern](../patterns/module-option-pattern.md)
   ([nh](../modules/nh.md) is the reference).
2. No import wiring — discovery is automatic per the
   [Dendritic module layout](../patterns/dendritic-modules.md). Prefix a path
   component with `_` to exclude it.
3. **`git add` the file** — flakes only see tracked files.
4. Enable it in a host (`modules/hosts/<host>.nix`):
   `kriswill.<name>.enable = true;`
5. Verify: `nix flake check`, then build or switch per
   [rebuild-and-rollback](rebuild-and-rollback.md).

Afterwards: run `bun scripts/okf/okf.ts scaffold` to stub the module's
catalog doc in this bundle, and `bun scripts/okf/okf.ts index` to list it.
