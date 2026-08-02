# languages

The languages this repository is authored in — one doc per language covering
how the repo uses it, the lint/format toolchain, and the editor wiring.
Their execution layer lives in [runtimes/](../runtimes/index.md).

## Concepts

* [Bash Language](bash.md) - Bash — the shell scripting substrate for standalone scripts and nix-embedded wrappers, under strict mode + shellcheck everywhere; the interactive shell is zsh, and new tooling prefers bun + TypeScript.
* [Lua Language](lua.md) - Lua — the small embeddable scripting language, used here in its Lua 5.1/LuaJIT dialect exclusively as the Neovim configuration language, formatted by stylua and served by lua-ls + lazydev.
* [Markdown Language](markdown.md) - Markdown — the repo's documentation language (this knowledge bundle, the docs/ manuals, agent instructions), linted and formatted by rumdl via efm, with MD013 deliberately disabled because prose reflow does more harm than good.
* [Nix Language](nix.md) - The lazy, pure, functional DSL every .nix file here is written in — evaluated by Determinate Nix, authored in dendritic idioms, kept clean by deadnix/statix/nixfmt and nil_ls.
* [Svelte Language](svelte.md) - Svelte — the compiler-based UI framework whose .svelte component language extends HTML; here it builds okf's viz-app in Svelte 5 runes syntax, backed by a full docs/svelt/ manual because most training data and web content is still Svelte 4.
* [TypeScript Language](typescript.md) - TypeScript — JavaScript with static types; this repo's default tooling language, executed directly by Bun with no tsc build step, spanning the okf CLI/viz-app, the skill drivers, and ccglass's patched upstream.
