# Svelte learnings & workarounds

Append-only log of gotchas, workarounds, and facts verified in practice.
Newest date first. Entry shape: `- **[area]** finding → fix/consequence (source, version)`.
When a learning is folded into a topic doc, the entry stays here as history.

## 2026-07-02

- **[this-repo]** Svelte LSP gap closed: `lsp/svelte.lua` (`svelteserver --stdio`,
  root markers `svelte.config.js|mjs|ts`/`package.json`/`.git`) + `"svelte"` in
  `vim.lsp.enable` + `svelte-language-server` (0.18.0) in `modules/darwin/neovim.nix`
  → verified headless: attaches with correct root and publishes diagnostics.
- **[this-repo]** `.svelte` files get **no format-on-save**: the repo's
  `BufWritePre` hook filters to efm only, and efm has no svelte formatter →
  svelteserver's own formatting is deliberately skipped; adding prettierd for
  svelte would require project-local `prettier-plugin-svelte` anyway. Format
  manually with `vim.lsp.buf.format({ filter = c.name == "svelte" })` if needed.
- **[tooling]** `@sveltejs/vite-plugin-svelte` 7.x peer-requires **Vite 8** →
  on Vite 5–7 projects pin plugin major 4/5/6 accordingly (npm registry peers, 2026-07-02).
- **[async]** `await` in components needs `compilerOptions.experimental.async: true`
  in `svelte.config.js` **and** an enclosing `<svelte:boundary>` with a `pending`
  snippet → default-on in Svelte 6, flag removed then (svelte.dev docs, 5.36+).
- **[kit]** Remote functions (`query`/`command`/`form`/`prerender` from
  `$app/server`) are still gated behind `kit.experimental.remoteFunctions: true`
  (Kit 2.27+, verified in 2.69 config types).
- **[runes]** Deriveds are directly assignable since 5.25 — the sanctioned
  optimistic-UI pattern; replaces effect-based hacks (svelte.dev $derived docs).
- **[templates]** `{@attach ...}` (5.29+) is the recommended replacement for
  `use:` actions; attachments are composable and spreadable (svelte.dev docs).
- **[kit]** `$app/state` replaces `$app/stores` since Kit 2.12 — `page.data`,
  no `$` prefix; old module still works (svelte.dev kit docs).
- **[testing]** Runes only compile in `.svelte`/`.svelte.js|ts` files — Vitest
  tests using runes must be named `*.svelte.test.ts` (svelte.dev testing docs).
- **[testing]** `vitest-browser-svelte` 2.x peer-requires Vitest 4 (npm registry).
- **[this-repo]** Neovim has the `svelte` treesitter grammar but **no Svelte
  LSP** — add `home/nvim/.config/nvim/lsp/svelte.lua` (svelteserver) before
  doing real Svelte work here.
- **[versions]** Baseline verified today: svelte 5.56.4, @sveltejs/kit 2.69.1,
  svelte-check 4.7, sv 0.16, prettier-plugin-svelte 4.1, eslint-plugin-svelte 3.20.
