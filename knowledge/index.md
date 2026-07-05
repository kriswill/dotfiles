---
okf_version: '0.1'
---

# knowledge

Authored knowledge for this repository — architecture patterns, decision
records, operational playbooks, and a catalog of every module, package, host,
and Neovim plugin — structured as an
[Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf)
v0.1 bundle. Conventions and tooling are documented in the
[OKF Profile](okf-profile.md). This bundle is the authored-rationale layer; it
complements [`AGENTS.md`](../AGENTS.md) (agent working instructions) and the
derived `.codebase-memory/` code graph.

## Concepts

* [Bun Runtime](bun-runtime.md) - Bun — the single-binary, JavaScriptCore-based JS/TypeScript runtime, bundler, test runner, and package manager; this repo's default script runtime, provisioned per-OS and consumed in three distinct modes by okf, ccglass, and qmd.
* [Task Manuals (docs/)](manuals.md) - Entry point to the docs/ manuals layer — task-focused, machine-verified operational references with dated learnings, complementing knowledge/'s durable rationale and catalog.
* [Nix Language](nix-language.md) - The lazy, pure, functional DSL every .nix file here is written in — evaluated by Determinate Nix, authored in dendritic idioms, kept clean by deadnix/statix/nixfmt and nil_ls.
* [OKF Profile](okf-profile.md) - This bundle's conventions on top of OKF v0.1 — required fields, link style, resource semantics, entry quality bar, type registry, and tooling.

## Subdirectories

* [decisions](decisions/index.md) - Decision records — why the repository is the way it is.
* [hosts](hosts/index.md) - The machines this flake configures, and which feature modules each enables.
* [modules](modules/index.md) - Catalog of darwin and NixOS feature modules, flake-parts plumbing modules, and nebula's host-specific files.
* [nvim](nvim/index.md) - The Neovim configuration — plugins, keymaps, LSP, and options for the Lua config tree under `home/nvim/`.
* [packages](packages/index.md) - Custom packages, nixpkgs overlays, and the self-contained sub-flakes the root flake consumes via relative-path inputs.
* [patterns](patterns/index.md) - Named architectural patterns this repository is built on.
* [playbooks](playbooks/index.md) - Operational how-tos for recurring tasks — rebuilds, adopting dotfiles, adding modules and packages, and keeping tooling up to date.
