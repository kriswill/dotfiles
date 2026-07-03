# Log

## 2026-07-02

- **Update** — viz polish: initial camera now fits the whole graph (aims at
  the layout centroid, backs off to fit the bounding sphere in both FOVs —
  no more small/off-center default view); embedded markdown files render as
  documents (raw md shipped instead of a highlighted source view, links
  resolve file-relative, doc heading styled as the panel title); and the
  detail panel gained a locked sticky header — back link or title crumb plus
  close — visible at any scroll depth on every view.

- **Update** — viz viewer rebuilt on Svelte 5 (runes) via bun-plugin-svelte
  inside the same one-shot `Bun.build` — componentized (Sidebar/Legend/
  Search/ConceptList/Stage/DetailPanel/Tooltip), a rune store with `$effect`
  bridges into the unchanged imperative `GraphScene`, all legacy contracts
  kept (`#data` blob, `window.__okf`, hash routing, panel-width
  localStorage). New: build-phase timings on every run, in-page startup
  marks (`__okf.perf`), `okf viz --perf` (headless-Chrome startup table)
  and `okf viz --check` (svelte-check), plus 52 bun tests. See
  [decision](decisions/viz-svelte-rebuild.md).

- **Update** — Svelte LSP wired into Neovim: `lsp/svelte.lua`
  (`svelteserver --stdio`), enabled in `lua/config/lsp.lua`, and
  `svelte-language-server` added to the [neovim module](modules/neovim.md)'s
  lsp-servers. [nvim/lsp](nvim/lsp.md) and `LANGUAGES.md` updated —
  svelteserver owns `.svelte` buffers (vtsls stays on plain js/ts); svelte
  has no efm formatter so format-on-save is a no-op there. Verified headless:
  attach with correct root + published diagnostics.

- **Creation** — Svelte manual under `docs/svelt/`: `manual.md` hub (cheat
  sheets, tooling, maintenance protocol) plus topic docs `runes.md`,
  `sveltekit.md`, `migration-svelte4-to-5.md`, and an append-only
  `learnings.md` gotcha log. Verified against svelte.dev llms.txt dumps and
  npm registry (svelte 5.56 / kit 2.69). Establishes the `docs/<tool>/`
  manual convention; noted gap: nvim has the svelte treesitter grammar but
  no Svelte LSP config.

- **Update** — viz layout: degree-adaptive forces for real clustering.
  Springs follow the d3-force recipe (strength ∝ 1/min-degree, shorter rest
  for leaf edges, pull biased onto the lower-degree endpoint) and repulsion
  is ForceAtlas2-style degree-weighted, so hubs shove apart and each keeps
  a tight star of satellites instead of one uniform ball.

- **Update** — viz camera: navigating to a node now flies to an exact
  landing (manual pan offsets no longer carry over and clip labels),
  approaches from opposite the node's neighbor centroid so its links fan
  out in view, and the idle auto-rotation is gone — the graph stays put.

- **Update** — Normalized all 30 `<https://…>` autolinks (24 files, mostly
  `Upstream:` lines in `nvim/plugins/`) to explicit inline markdown links.
  The viz markdown renderer also learned pipe tables and autolink syntax,
  and the embedded source-file view now renders `https://` URLs as links.

- **Creation** — New `nvim/` knowledge area covering the whole Neovim
  configuration: core concepts ([architecture](nvim/architecture.md),
  [options](nvim/options.md), [keymaps](nvim/keymaps.md),
  [lsp](nvim/lsp.md), [filetypes](nvim/filetypes.md)) plus a per-plugin
  catalog (23 docs under `nvim/plugins/`). Two decision records added:
  [native vim.pack](decisions/native-vim-pack.md) and
  [efm umbrella formatting](decisions/efm-umbrella-formatting.md).
  `okf scaffold` gained a neovim-plugins pass (stubs
  `nvim/plugins/<name>.md` from `lua/plugins/` specs); type registry gained
  `Neovim Plugin` and `Neovim Config`. Source-side staleness spotted while
  authoring was fixed in a sibling commit: `LANGUAGES.md`'s retired
  home-manager module path, `ftplugin/markdown.lua`'s pre-stow `spellfile`
  path, and duplicate `<leader>n` / `<M-B>` keymap definitions.

- **Update** — `okf viz` rebuilt as a 3D orbit view in the style of
  codebase-memory-mcp's graph-ui: Three.js instanced glow spheres + bloom,
  frozen generation-time layout (`scripts/okf/layout3d.ts`), viewer app in
  `scripts/okf/viz-app/` bundled by bun into the single offline page.

- **Update** — `okf viz` now embeds every referenced source file
  (syntax-highlighted at generation time); `resource:` paths and repo-file
  links in the detail panel open an in-panel code preview with metadata and
  referencing concepts.

- **Update** — `okf` is now a dev-shell command (a `writeShellApplication`
  wrapper in `modules/dev.nix` that resolves the live checkout via git);
  [dev](modules/dev.md) and the [OKF Profile](okf-profile.md) tooling section
  updated to match.

- **Creation** — Bundle created as an OKF v0.1 proof of concept. Seeded with 5
  pattern docs, 6 decision records, 6 playbooks, and 45 scaffolded catalog
  stubs (modules, hosts, packages, sub-flakes). Tooling lives in
  `scripts/okf/` (`scaffold` / `index` / `validate` / `viz`); conventions in
  [okf-profile.md](okf-profile.md).
