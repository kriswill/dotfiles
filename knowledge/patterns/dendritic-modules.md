---
type: Pattern
title: Dendritic Module Layout
description: Every .nix file under modules/ is auto-discovered as a flake-parts module via import-tree — no manual import lists anywhere.
resource: flake.nix
tags: [flake-parts, import-tree, architecture]
timestamp: '2026-07-02T00:00:00-07:00'
---

The flake is organized in the **Dendritic pattern**: `flake.nix` calls
`flake-parts.lib.mkFlake` with `import-tree ./modules`, so every `.nix` file
under `modules/` is discovered and imported as a flake-parts module
automatically. There is no central import list to maintain — adding a file
*is* registering it.

Key consequences:

- Feature modules contribute to shared option namespaces
  (`flake.modules.darwin.<name>`); the plumbing module
  [darwin](../modules/darwin.md) then realises
  `configurations.darwin.<host>` into `darwinConfigurations`.
- A path component prefixed with `_` is excluded from discovery
  (e.g. `yazi/_themes/`) — the escape hatch for non-module files that must
  live under `modules/`.
- Pure helpers live in `lib/` *outside* `modules/` precisely so import-tree
  skips them; they're merged onto `nixpkgs.lib` by the
  [lib](../modules/lib.md) plumbing module and reach darwin modules via
  `specialArgs`.
- **Flakes only see git-tracked files** — a new module must be `git add`ed
  before `nix build` can see it (the most common gotcha; see the
  [add-module playbook](../playbooks/add-module.md)).

Feature modules follow the [module option pattern](module-option-pattern.md).

## Citations

- [flake-parts](https://flake.parts/)
- [import-tree](https://github.com/vic/import-tree)
- [Dendritic pattern](https://github.com/mightyiam/dendritic)
