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

* [Bash Language](bash-language.md) - Bash — the shell scripting substrate for standalone scripts and nix-embedded wrappers, under strict mode + shellcheck everywhere; the interactive shell is zsh, and new tooling prefers bun + TypeScript.
* [Bun Runtime](bun-runtime.md) - Bun — the single-binary, JavaScriptCore-based JS/TypeScript runtime, bundler, test runner, and package manager; this repo's default script runtime, provisioned per-OS and consumed in three distinct modes by okf, ccglass, and qmd.
* [Lua Language](lua-language.md) - Lua — the small embeddable scripting language, used here in its Lua 5.1/LuaJIT dialect exclusively as the Neovim configuration language, formatted by stylua and served by lua-ls + lazydev.
* [Task Manuals (docs/)](manuals.md) - Entry point to the docs/ manuals layer — task-focused, machine-verified operational references with dated learnings, complementing knowledge/'s durable rationale and catalog.
* [Markdown Language](markdown-language.md) - Markdown — the repo's documentation language (this knowledge bundle, the docs/ manuals, agent instructions), linted and formatted by rumdl via efm, with MD013 deliberately disabled because prose reflow does more harm than good.
* [Nix Language](nix-language.md) - The lazy, pure, functional DSL every .nix file here is written in — evaluated by Determinate Nix, authored in dendritic idioms, kept clean by deadnix/statix/nixfmt and nil_ls.
* [OKF Profile](okf-profile.md) - This bundle's conventions on top of OKF v0.1 — required fields, link style, resource semantics, entry quality bar, type registry, and tooling.
* [Svelte Language](svelte-language.md) - Svelte — the compiler-based UI framework whose .svelte component language extends HTML; here it builds okf's viz-app in Svelte 5 runes syntax, backed by a full docs/svelt/ manual because most training data and web content is still Svelte 4.
* [TypeScript Language](typescript-language.md) - TypeScript — JavaScript with static types; this repo's default tooling language, executed directly by Bun with no tsc build step, spanning the okf CLI/viz-app, the skill drivers, and ccglass's patched upstream.

## Subdirectories

* [decisions](decisions/index.md) - Decision records — why the repository is the way it is.
* [hosts](hosts/index.md) - The machines this flake configures, and which feature modules each enables.
* [modules](modules/index.md) - Catalog of darwin and NixOS feature modules, flake-parts plumbing modules, and nebula's host-specific files.
* [nvim](nvim/index.md) - The Neovim configuration — plugins, keymaps, LSP, and options for the Lua config tree under `home/nvim/`.
* [packages](packages/index.md) - Custom packages, nixpkgs overlays, and the self-contained sub-flakes the root flake consumes via relative-path inputs.
* [patterns](patterns/index.md) - Named architectural patterns this repository is built on.
* [playbooks](playbooks/index.md) - Operational how-tos for recurring tasks — rebuilds, adopting dotfiles, adding modules and packages, and keeping tooling up to date.
