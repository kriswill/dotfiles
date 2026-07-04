---
type: Decision
title: Viz Viewer — Svelte 5 on the Pure-Bun One-Shot Pipeline
description: Rebuild the okf viz viewer on Svelte 5 runes via bun-plugin-svelte inside the existing single Bun.build call, keeping the self-contained viz.html output and wrapping the imperative Three.js scene instead of rewriting it.
tags: [viz, svelte, tooling]
timestamp: '2026-07-02T00:00:00-07:00'
---

**Status:** active. **Where:** `flakes/okf/viz-app/`, built by
[../../flakes/okf/viz.ts](../../flakes/okf/viz.ts).

## Context

The viz viewer was ~840 lines of hand-rolled TypeScript: module-level `let`
state, `innerHTML` DOM assembly, no framework, no tests, no type-checking,
and no timing instrumentation. Rebuilding it componentized and reactive
raised a tooling tension: the repo's Svelte research (`docs/svelt/`) assumes
Vite, while okf is a deliberately minimal one-shot `Bun.build` pipeline that
inlines everything into one offline `knowledge/viz.html` — a hard constraint,
since the page is meant to eventually publish as public repo documentation.

## Decision

Adopt **Svelte 5 (runes) compiled by `bun-plugin-svelte` inside the existing
`Bun.build` call** — no Vite, no dev server, no config files beyond a
`tsconfig.json` and `bunfig.toml`. A spike gate proved the 0.0.x plugin
handles `lang="ts"`, runes, `.svelte.ts` modules, and emits component CSS as
a build artifact that viz.ts inlines next to the JS (Vite 8 +
`@sveltejs/vite-plugin-svelte` 7 was the documented fallback; never needed).
Architecture: an immutable data model (`data.ts`), a rune store
(`state.svelte.ts`) with `$effect` bridges in `Stage.svelte` driving the
**unchanged imperative `GraphScene`** (setDim/setSelected/applyTheme/
setViewShift), and components for sidebar, legend, search, list, tooltip,
and detail panel. Legacy contracts preserved exactly: the `#data` JSON blob,
`window.__okf` hook, `#c/`/`#f/` hash routing, and localStorage panel width.
Performance is now measured: build-phase timings print on every `okf viz`
run, the page records `performance.mark`s on `__okf.perf`, and
`okf viz --perf` drives headless Chrome (puppeteer-core against system
Chrome — chosen over ~150 lines of hand-rolled CDP) to print a startup
table. `okf viz --check` runs svelte-check; `bun test` covers markdown,
hash codec, data model, rune store, components, and the scene bridges
(52 tests). Under `bun test` the plugin cannot run (its virtual CSS modules
need build-time resolution), so a small preload loader compiles via
`svelte/compiler` directly — see `docs/svelt/learnings.md` 2026-07-02.

## Consequences

- The pipeline stays pure bun — one command, one output file; bundle grew
  ~78 KB (Svelte runtime + component CSS) on a three.js-dominated ~1.1 MB.
- Viewer logic is now typed (strict tsconfig, svelte-check clean) and unit
  tested; the reactive store makes state transitions explicit instead of
  scattered DOM mutations.
- `bun-plugin-svelte` is 0.0.x: bumps deserve a re-run of the spike gate
  (runes, `.svelte.ts`, CSS artifact) before landing.
- No HMR/dev server — iterating means regenerating viz.html; acceptable at
  ~1.3 s total build.
- `--perf` depends on a system Chrome at the default macOS path or
  `PUPPETEER_EXECUTABLE_PATH`.

## Citations

- [bun-plugin-svelte](https://www.npmjs.com/package/bun-plugin-svelte) 0.0.6
  under bun 1.3.13, svelte 5.56.4 (npm registry, verified 2026-07-02)
- [Svelte docs](https://svelte.dev/docs/svelte/overview) — runes,
  `{@attach}`, `svelte/reactivity`
- [../../docs/svelt/learnings.md](../../docs/svelt/learnings.md) — spike
  gate outcome and bun-test loader recipe
- Baseline parity verified against the pre-rebuild viz.html (screenshots,
  `__okf` hooks, hash routing, dark mode) via chrome-devtools
