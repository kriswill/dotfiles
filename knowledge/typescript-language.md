---
type: Reference
title: TypeScript Language
description: 'TypeScript — JavaScript with static types; this repo''s default tooling language, executed directly by Bun with no tsc build step, spanning the okf CLI/viz-app, the skill drivers, and ccglass''s patched upstream.'
tags: [typescript, language]
timestamp: '2026-07-04T00:00:00-07:00'
---

[TypeScript](https://www.typescriptlang.org/) is JavaScript with syntax for
static types — a superset whose types are checked before execution and
erased at runtime, leaving plain JavaScript.

## How this repo uses it

**It is the default tooling language** (house rule: bun + TS over
bash/python — see [Bun runtime](bun-runtime.md)): the [okf](packages/okf.md)
CLI and its Svelte viz-app, the skill drivers
(`.claude/skills/patch-ccglass/driver.ts`, `derivation-to-flake`'s
scripts), and [ccglass](packages/ccglass.md)'s patched upstream are all TS.

**There is no tsc build step anywhere** — bun transpiles on execution, so
types are documentation-plus-editor-tooling by default. Typechecking is
opt-in and targeted: `okf viz --check` runs svelte-check over the viewer.

**Editor tooling** splits by file type ([nvim LSP](nvim/lsp.md)): vtsls
serves plain `.ts`/`.tsx` (workspace TypeScript SDK, inlay hints) while the
[svelte](svelte-language.md) language server owns TS embedded in `.svelte`
files — deliberately
scoped so the two never fight over a buffer. Formatting is biome via efm,
with root markers narrowed to real `biome.json` files.

## Citations

- [typescriptlang.org](https://www.typescriptlang.org/) — official site
- [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/intro.html)
