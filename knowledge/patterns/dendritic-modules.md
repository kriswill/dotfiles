---
type: Pattern
title: Dendritic Module Layout
description: Every .nix file under modules/ is auto-discovered as a flake-parts module via import-tree — no manual import lists anywhere.
resource: flake.nix
tags: [flake-parts, import-tree, architecture]
timestamp: '2026-07-03T12:00:00-07:00'
---

The flake is organized in the **Dendritic pattern**: `flake.nix` calls
`flake-parts.lib.mkFlake` with `import-tree ./modules`, so every `.nix` file
under `modules/` is discovered and imported as a flake-parts module
automatically. There is no central import list to maintain — adding a file
*is* registering it.

Key consequences:

- Feature modules contribute to shared option namespaces
  (`flake.modules.<class>.<name>`, classes `darwin` and `nixos`); two plumbing
  realisers — [darwin](../modules/darwin.md) (`configurations.darwin.<host>`
  → `darwinConfigurations`) and [nixos](../modules/nixos.md)
  (`configurations.nixos.<host>` → `nixosConfigurations`, through
  snowglobe-lib's `mkNixosHost`) — turn registrations into outputs (see
  [host registry realisers](host-registry-realisers.md)).
- A path component prefixed with `_` is excluded from discovery
  (e.g. `yazi/_themes/`) — the escape hatch for non-module files that must
  live under `modules/`.
- Pure helpers live in `lib/` *outside* `modules/` precisely so import-tree
  skips them; the [darwin](../modules/darwin.md) realiser merges them onto
  `nixpkgs.lib` inline and hands the result to darwin modules via
  `specialArgs`. The nixos evaluation (through `mkNixosHost`) does **not**
  get the extended lib — nixos modules import `lib/` files by path
  (`lib/direnv-nom-wrapper.nix`; see
  [cross-OS module twins](cross-os-module-twins.md)).
- **Flakes only see git-tracked files** — a new module must be `git add`ed
  before `nix build` can see it (the most common gotcha; see the
  [add-module playbook](../playbooks/add-module.md)).

Feature modules are mounted ungated per the
[host-mounted modules pattern](host-mounted-modules.md).

## Citations

- [flake-parts](https://flake.parts/)
- [import-tree](https://github.com/vic/import-tree)
- [Dendritic pattern](https://github.com/mightyiam/dendritic)
