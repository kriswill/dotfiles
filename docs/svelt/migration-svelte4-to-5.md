# Migrating Svelte 4 → 5

Translation table for reading old code, tutorials, and LLM output written in
Svelte 4. Automated migration: `npx sv migrate svelte-5` handles most of it.
Svelte 4 syntax still *runs* in 5 ("legacy mode", per-component), but don't
write new code in it — and never mix runes and legacy reactivity in one file.

## Syntax mapping

| Svelte 4 | Svelte 5 |
| --- | --- |
| `let count = 0` (implicitly reactive) | `let count = $state(0)` |
| `$: doubled = count * 2` | `let doubled = $derived(count * 2)` |
| `$: { sideEffect(); }` | `$effect(() => { sideEffect(); })` |
| `export let prop = 'default'` | `let { prop = 'default' } = $props()` |
| `$$props` / `$$restProps` | `let { ...rest } = $props()` |
| `on:click={fn}` | `onclick={fn}` |
| `on:click\|preventDefault` (modifiers) | Call `e.preventDefault()` in the handler; `capture` via `onclickcapture`; others via `on()` from `svelte/events` |
| `createEventDispatcher()` + `on:save` | Callback props: `let { onsave } = $props()`; call `onsave(detail)` |
| `<slot />` | `{@render children?.()}` + `let { children } = $props()` |
| `<slot name="x" />` / `<div slot="x">` | Named snippet props: `{#snippet x()}` passed as props, `{@render x()}` |
| `<slot prop={value} />` (let:) | Snippet parameters: `{@render row(item)}` |
| `$$slots.x` | `{#if x}` (snippet prop is just a value) |
| `new Component({ target })` | `mount(Component, { target })` from `svelte` |
| `component.$set(...)` / `.$destroy()` | Mutate `$state` props object / `unmount(app)` |
| `component.$on('event', fn)` | Pass callback prop in `mount(..., { events })` — or just props |
| `beforeUpdate` / `afterUpdate` | `$effect.pre` / `$effect` (scoped to actual deps) |
| `tick()` | Still exists; `await tick()` after state change |
| `use:action` | Still works; prefer `{@attach fn}` (≥5.29) |
| Store for shared state | `$state` in a `.svelte.js` module ([runes.md](runes.md)) |
| `svelte/store` `$store` syntax | Still supported — no need to migrate stores wholesale |

## Behavioral changes that bite

- **Components are functions, not classes.** Anything doing
  `new Component(...)` (tests, integrations) needs `mount`/`hydrate`.
  `render` from `svelte/server` for SSR strings.
- **Reactivity is runtime, not compile-time.** Assignment-triggers-update on
  plain `let` is gone; class fields need explicit `$state`.
- **Touch events are passive** (`ontouchstart`/`ontouchmove`) — can't
  `preventDefault` without `on()` from `svelte/events`.
- **Stricter attributes**: complex values must be quoted (`prop="a{b}c"`).
- **`children` is a reserved prop name** (implicit content snippet).
- **Bindings need `$bindable()`** on the child; Svelte 4 allowed binding any prop.
- **`accessors`/`immutable` component options are ignored** in runes mode.
- **CSS scoping** now uses `:where(...)`-based selectors — specificity of
  scoped styles changed slightly vs 4.
- Whitespace handling and attribute casing are more spec-normal; run the
  visual diff after migrating anything layout-sensitive.

## SvelteKit 1 → 2 (short version)

- `error()`/`redirect()` are **called, not thrown**.
- `cookies.set` requires an explicit `path`.
- Top-level promises returned from `load` are not auto-awaited.
- Dynamic env (`$env/dynamic/*`) unavailable during prerender.
- `use:enhance` callbacks lost `form`/`data` args → use `formData`.
- `$app/stores` → `$app/state` (≥2.12).
- Needs Node ≥18.13, Vite 5+ / vite-plugin-svelte 3+.
