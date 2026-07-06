---
type: Reference
title: Svelte Language
description: 'Svelte — the compiler-based UI framework whose .svelte component language extends HTML; here it builds okf''s viz-app in Svelte 5 runes syntax, backed by a full docs/svelt/ manual because most training data and web content is still Svelte 4.'
tags: [svelte, language]
timestamp: '2026-07-04T00:00:00-07:00'
---

[Svelte](https://svelte.dev) is a UI framework built around a compiler: the
`.svelte` component language extends HTML, and components compile to
imperative DOM updates with no virtual DOM. Svelte 5 replaced its implicit
reactivity with **runes** (`$state`, `$derived`, `$effect`).

## How this repo uses it

**One Svelte codebase:** [okf](packages/okf.md)'s viz-app — the knowledge
graph viewer — rebuilt in Svelte 5 from a vanilla-TS canvas prototype (see
the [viz-svelte-rebuild decision](decisions/viz-svelte-rebuild.md)). It is
bundled at CLI runtime by `Bun.build` + bun-plugin-svelte
([Bun runtime](bun-runtime.md)), typechecked by svelte-check
(`okf viz --check`), and tested under `bun test`.

**The house Svelte knowledge lives in
[`docs/svelt/`](../docs/svelt/manual.md)** (see
[Task Manuals](manuals.md)) — a machine-verified manual whose ground rule
is: always write Svelte 5 runes syntax, and translate anything found in
tutorials, Stack Overflow, or LLM output via its Svelte-4→5 migration map
first, because most of that corpus predates runes.

**Editor tooling** ([nvim LSP](nvim/lsp.md)): the svelte language server
owns `.svelte` files including their embedded JS/TS/CSS, with vtsls
deliberately scoped away ([TypeScript](typescript-language.md)); svelte is
not in efm's language table, so `.svelte` files never auto-format.

## Citations

- [svelte.dev](https://svelte.dev) — official site and docs (LLM dumps at
  `svelte.dev/llms.txt`)
- [`docs/svelt/manual.md`](../docs/svelt/manual.md) — in-repo manual,
  version-stamped and verified against svelte.dev
