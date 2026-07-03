# Svelte learnings & workarounds

Append-only log of gotchas, workarounds, and facts verified in practice.
Newest date first. Entry shape: `- **[area]** finding → fix/consequence (source, version)`.
When a learning is folded into a topic doc, the entry stays here as history.

## 2026-07-02

- **[runes]** Don't name a prop/variable `state`: with runes/legacy
  auto-detection, a `.svelte` file that has a binding named `state` in scope
  compiles `$state(...)` as a legacy **store subscription to that binding** →
  runtime `store_invalid_shape` ("`state` is not a store"). Fix both ways:
  pass `runes: true` in compile options (and
  `compilerOptions: { runes: true }` to bun-plugin-svelte) and rename the
  binding (`viz` here). Note `compileModule()` has **no** `runes` option —
  `.svelte.ts` modules are always runes-mode (svelte 5.56).
- **[testing]** Dependency-hint statements like `void someRune;` inside
  `.svelte.ts` are unreliable when the file passes through `Bun.Transpiler`
  before `compileModule` (bun test loader) — the side-effect-free expression
  can be dropped, silently killing the reactive edge. Make dependencies real
  values instead (e.g. reassign a `$state` object) or read the rune
  explicitly in the consuming `$effect` body (verified bun 1.3.13).
- **[tooling]** `bun-plugin-svelte` 0.0.6 + bun 1.3.13 `Bun.build` gate **passed**
  for the okf viz rebuild: `.svelte` with `lang="ts"`, runes, `{@attach}`, scoped
  `<style>`, and `.svelte.ts` rune modules all compile (target browser →
  `generate: "client"` auto-selected); component CSS comes out as a separate
  `kind: "asset"` `.css` artifact in `build.outputs` (plugin hardcodes
  `css: "external"`) → inline it into the HTML `<style>` yourself. Verified
  end-to-end in headless Chrome: reactivity, shared-store state, attachment,
  scoped CSS all work.
- **[testing]** `bun-plugin-svelte` **cannot be used under `bun test`**: client
  components emit virtual `bun-svelte:*.css` imports resolved via `onResolve`,
  but bun runtime plugins' `onResolve` never fires (verified 1.3.13) → "Cannot
  find package 'bun-svelte:…css'". Fix: `[test].preload` a ~25-line loader that
  calls `svelte/compiler` `compile()` (`generate: "client"`, `css: "injected"`)
  for `.svelte` and `compileModule()` (after `Bun.Transpiler` TS strip) for
  `.svelte.ts` — no virtual modules, tests pass.
- **[testing]** `bun test` resolves package exports with the **default (server)
  condition** and has no `--conditions` flag → `import { mount } from "svelte"`
  hits `index-server.js` ("mount(...) is not available on the server"). Fix in
  the same preload: `onLoad` filter on `svelte/src/**/index-server.js` returning
  the sibling `index-client.js` contents (same dir, relative imports unchanged).
- **[testing]** Svelte 5 `mount()`/`unmount()` + rune reactivity work under
  happy-dom 20.10 (`@happy-dom/global-registrator` preload) in `bun test`;
  assert after `flushSync()` (bun 1.3.13, svelte 5.56.4).
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
