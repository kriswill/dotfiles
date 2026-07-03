# Svelte manual

Working manual for Svelte 5 + SvelteKit 2. The cheat sheets below cover most
day-to-day syntax; topic files go deeper. All content verified against the
svelte.dev docs on **2026-07-02** (svelte 5.56.4, @sveltejs/kit 2.69.1,
vite-plugin-svelte 7.x on Vite 8, sv CLI 0.16).

## Doc map

| File | Covers |
| --- | --- |
| `manual.md` (this file) | Quick start, syntax cheat sheets, tooling, maintenance protocol |
| [runes.md](runes.md) | Reactivity in depth: every rune, `.svelte.js` modules, stores interop, async |
| [sveltekit.md](sveltekit.md) | Routing, load, form actions, remote functions, hooks, env, adapters |
| [migration-svelte4-to-5.md](migration-svelte4-to-5.md) | Old→new syntax mapping (most web content is still Svelte 4) |
| [learnings.md](learnings.md) | Dated log of gotchas and workarounds hit in practice |

## Ground rules

- **Always write Svelte 5 (runes) syntax.** Most tutorials, Stack Overflow
  answers, and LLM training data are Svelte 4 — translate via
  [migration-svelte4-to-5.md](migration-svelte4-to-5.md) before trusting them.
- Runes (`$state` etc.) only work in `.svelte` files and `.svelte.js`/`.svelte.ts` modules.
- Authoritative source: <https://svelte.dev>. LLM-friendly dumps:
  `svelte.dev/llms.txt` (index), `svelte.dev/docs/svelte/llms.txt`,
  `svelte.dev/docs/kit/llms.txt`, `svelte.dev/llms-small.txt` (abridged).
  Fetch these to re-verify anything in this manual.

## Quick start

```sh
npx sv create my-app      # interactive scaffold: SvelteKit, TS, addons
cd my-app && npm install
npm run dev               # Vite dev server (default :5173)
npm run build             # production build via adapter
npm run preview           # serve the production build locally
npx sv add tailwindcss    # add integrations later (drizzle, mdsvex, ...)
npx sv check              # typecheck .svelte files (svelte-check)
npx sv migrate svelte-5   # auto-migrate Svelte 4 code
```

## Component anatomy

```svelte
<script module>
  // runs once per module (rarely needed); exports allowed
</script>

<script>
  // runs per instance; runes live here
  let { name = 'world', children } = $props();
  let count = $state(0);
</script>

<button onclick={() => count++}>{name}: {count}</button>
{@render children?.()}

<style>
  /* scoped to this component by default; :global(...) to escape */
  button { color: tomato; }
</style>
```

## Runes cheat sheet

Full semantics and pitfalls: [runes.md](runes.md).

| Rune | Purpose |
| --- | --- |
| `$state(v)` | Reactive state; objects/arrays become deeply reactive proxies |
| `$state.raw(v)` | No deep reactivity — update by reassignment only |
| `$state.snapshot(v)` | Plain (non-proxy) clone, for external APIs / `structuredClone` |
| `$derived(expr)` | Computed value; side-effect free; re-runs when deps change |
| `$derived.by(fn)` | Same, but takes a function for multi-line derivations |
| `$effect(fn)` | Side effect after DOM update; return a cleanup fn. Escape hatch — see runes.md before reaching for it |
| `$effect.pre(fn)` | Like `$effect`, but before DOM update |
| `$props()` | Destructure component props: `let { a, b = 1, ...rest } = $props()` |
| `$props.id()` | SSR-safe unique id per component instance |
| `$bindable()` | Mark a prop as two-way bindable: `let { value = $bindable() } = $props()` |
| `$inspect(v)` | Dev-only reactive `console.log`; `.with(fn)` to customize; `$inspect.trace()` to debug effect re-runs |
| `$host()` | The host element, when compiled as a custom element |

## Template syntax cheat sheet

```svelte
{#if cond}...{:else if other}...{:else}...{/if}

{#each items as item, i (item.id)}...{:else}<!-- empty list -->{/each}
{#each { length: 5 }, i}...{/each}

{#await promise}pending{:then value}...{:catch err}...{/await}

{#key expr}<!-- recreated when expr changes -->{/key}

{#snippet row(item)}<li>{item}</li>{/snippet}
{@render row(x)}                <!-- snippets replace slots -->

{@html rawString}               <!-- XSS: only trusted content -->
{@const area = w * h}           <!-- local const inside a block -->
{@attach (el) => { ... }}       <!-- run fn on mount / state change; ≥5.29, prefer over use: -->
```

- **Events are plain attributes**: `onclick={fn}`, `{onclick}` shorthand,
  spreads work. No `on:` directive, no modifiers — call
  `e.preventDefault()` yourself, or use `on()` from `svelte/events`.
  Component "events" are just callback props.
- **Bindings**: `bind:value`, `bind:checked`, `bind:group`, `bind:files`,
  `bind:this={el}`; dimension bindings (`bind:clientWidth` …) are readonly.
  Function bindings `bind:value={get, set}` for validation/transforms (≥5.9).
  Component props need `$bindable()` on the child side.
- **class/style**: `class` accepts strings, objects, or arrays with clsx
  semantics (≥5.16): `class={['btn', { active }]}`. `style:prop={v}` and
  `class:name={cond}` directives still exist.
- **Transitions**: `transition:fade`, `in:`/`out:`, `animate:flip` (with
  keyed each) — unchanged from Svelte 4; import from `svelte/transition`,
  `svelte/animate`, `svelte/easing`.
- **Special elements**: `<svelte:window>`, `<svelte:document>`,
  `<svelte:body>`, `<svelte:head>`, `<svelte:element this={tag}>`,
  `<svelte:boundary>` (error/async boundary), `<svelte:options>`.

## Instantiating components

Components are functions, not classes. From JS:

```js
import { mount, unmount, hydrate } from 'svelte';
import App from './App.svelte';

const app = mount(App, { target: document.body, props: { name: 'k' } });
// hydrate(App, ...) over server-rendered HTML; unmount(app) to destroy
```

Server-side: `import { render } from 'svelte/server'` → `{ body, head }`.

## TypeScript

```svelte
<script lang="ts">
  import type { Snippet } from 'svelte';
  import type { HTMLButtonAttributes } from 'svelte/elements';

  interface Props extends HTMLButtonAttributes {
    label: string;
    children?: Snippet;
  }
  let { label, children, ...rest }: Props = $props();
</script>
```

`ComponentProps<typeof Button>` extracts a component's prop types.

## Tooling

| Package | Major (2026-07) | Notes |
| --- | --- | --- |
| `svelte` | 5.56 | Runes are current; Svelte 6 will make async default |
| `@sveltejs/kit` | 2.69 | See [sveltekit.md](sveltekit.md) |
| `@sveltejs/vite-plugin-svelte` | 7.x | **Peer-requires Vite 8**; use 5.x/6.x on older Vite |
| `svelte-check` | 4.x | CLI typechecker; `npx sv check` |
| `sv` | 0.16 | Official CLI: create/add/migrate/check |
| `prettier-plugin-svelte` | 4.x | Formatting |
| `eslint-plugin-svelte` | 3.x | Linting |

- Editor: VS Code `svelte.svelte-vscode`; the language server is
  `svelte-language-server` (binary `svelteserver`).
- **This repo's Neovim**: the `svelte` treesitter grammar is installed
  (`home/nvim/.config/nvim/lua/plugins/treesitter.lua`) but **no Svelte LSP
  is configured** — for real Svelte work add
  `home/nvim/.config/nvim/lsp/svelte.lua` (svelteserver) alongside `vtsls`.
- Testing: Vitest. Test runes-using code in files named `*.svelte.test.ts`.
  Component testing: `vitest-browser-svelte` (needs Vitest 4) or
  `@testing-library/svelte`.

## Maintaining this manual

Same protocol as other manuals in `docs/`:

1. **Record learnings immediately.** Any gotcha, workaround, or
   surprising behavior discovered while working with Svelte goes in
   [learnings.md](learnings.md) under today's date, newest first.
2. **Fold durable facts into topic docs.** When a learning proves stable,
   integrate it into the right file above; the log entry stays as history.
3. **Re-verify before trusting version-sensitive claims.** Fetch
   `svelte.dev/docs/svelte/llms.txt` / `docs/kit/llms.txt` and check npm
   (`https://registry.npmjs.org/<pkg>/latest`) — then update the versions in
   the header and Tooling table, and note the verification date.
4. **Keep it scannable.** Tables and short snippets over prose; deep dives
   belong in topic files, not here. Markdown is linted by rumdl
   (`rumdl.toml`; MD013 line-length disabled, single-H1 rule applies).
