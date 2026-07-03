# Runes & reactivity

Deep dive on Svelte 5 reactivity. Quick reference lives in
[manual.md](manual.md); this file covers semantics and the pitfalls that
actually bite. Runes work in `.svelte` files and `.svelte.js`/`.svelte.ts`
modules only.

## $state

```js
let count = $state(0);          // read/write `count` directly — no wrapper
let todos = $state([{ done: false }]);
todos[0].done = true;           // deep updates are reactive (proxy)
```

- Objects/arrays are wrapped in **deeply reactive proxies**; primitives are not wrapped.
- **Class instances are NOT proxied.** `$state(new Foo())` does nothing —
  declare reactive fields inside the class instead: `class Foo { value = $state(0) }`.
- `$state.raw(v)` — opt out of deep reactivity; updates only via reassignment.
  Cheaper for large immutable-style data.
- `$state.snapshot(v)` — plain clone of the proxy, for `structuredClone`,
  logging, or libraries that choke on proxies.
- `$state.eager(v)` — reflect a change in the UI immediately even when an
  `await` expression would otherwise synchronize the update (async mode).
- Destructuring breaks reactivity: `const { done } = todos[0]` captures the
  value at that moment. Keep the object reference, or use getters.

## $derived

```js
let count = $state(0);
let doubled = $derived(count * 2);          // expression, not a function
let sorted = $derived.by(() => [...items].sort(cmp));  // function form
```

- Must be side-effect free; Svelte disallows state mutation inside.
- Dependencies are tracked at runtime — anything read synchronously.
  Exclude a dependency with `untrack(fn)` (from `svelte`).
- **Deriveds are writable (≥5.25):** assigning to one overrides it until the
  next dependency change — the idiomatic optimistic-UI pattern. No effects needed.
- Not deeply reactive: a derived object is returned as-is.
- Lazy: not recomputed until read; unchanged references skip downstream updates.

## $effect

Escape hatch — most "I need an effect" cases are something else:

| You want to… | Use instead |
| --- | --- |
| Compute state from other state | `$derived` |
| Reassign a computed value (optimistic UI) | writable `$derived` |
| Sync with a DOM element / external lib (D3 etc.) | `{@attach ...}` |
| React to a user interaction | event handler / function binding |
| Log for debugging | `$inspect` |
| Subscribe to something external | `createSubscriber` from `svelte/reactivity` |
| Link two values ("money spent"/"money left") | function bindings or writable derived |

Legit uses: imperative third-party APIs, canvas drawing, analytics calls.

```js
$effect(() => {
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = color;               // re-runs when `color` changes
  return () => { /* cleanup: runs before re-run and on destroy */ };
});
```

- Runs after mount and after DOM updates, in a microtask, **client only**
  (never during SSR — don't wrap contents in `if (browser)`).
- Only **synchronously** read state is tracked. State read after an `await`
  or inside `setTimeout` is not a dependency.
- **Never set state inside an effect** — infinite-loop and staleness bait.
  If you truly must write state read in the same effect, `untrack` the read.
- Variants: `$effect.pre` (before DOM update), `$effect.tracking()` (am I in
  a tracking context?), `$effect.root(fn)` (manually-disposed non-tracked
  scope, for effects outside component init), `$effect.pending()` (count of
  pending promises in the current boundary — async mode).

## $props / $bindable

```svelte
<script>
  let {
    required,
    optional = 'fallback',     // default, applied when prop is undefined
    class: klass,              // rename reserved words
    value = $bindable(0),      // parent may (not must) bind:value
    ...rest                    // rest props (readonly)
  } = $props();

  const uid = $props.id();     // SSR-safe unique id, stable across hydration
</script>
```

- Props are reactive when the parent's value changes; don't mutate un-bound
  props (warning: `ownership_invalid_mutation`).
- `$bindable` with a fallback: if the parent binds, it must not pass `undefined`.

## $inspect / $host

- `$inspect(a, b)` — dev-only, re-logs on any (deep) change.
  `$inspect(v).with((type, v) => ...)` for custom handling (`type` is `"init" | "update"`).
- `$inspect.trace('label')` as the first line of an effect/derived logs which
  dependency triggered each re-run.
- `$host()` — the host element inside a component compiled with
  `<svelte:options customElement="my-el" />`.

## Shared state: `.svelte.js` / `.svelte.ts` modules

Runes work in these modules — this replaces most store usage:

```js
// counter.svelte.js
export const counter = $state({ value: 0 });        // export an OBJECT — fine

let count = $state(0);                               // primitive:
export function getCount() { return count; }        // export accessors,
export function increment() { count += 1; }         // NOT `export let count`
```

You cannot export a `$state` variable that gets reassigned — importers would
capture a stale binding (compile error `state_referenced_locally` territory).
Export objects (mutate properties) or getter/setter functions, or use a class.

## Stores (`svelte/store`) — still fine, mostly legacy

- `$store` auto-subscription syntax still works everywhere.
- Reach for stores only for: async/stream-shaped data pipelines,
  `writable`/`readable` interop with existing libraries, or pre-5 codebases.
  New code: runes + `.svelte.js` modules.
- `toStore` / `fromStore` (from `svelte/store`) bridge the two worlds.

## Built-in reactive utilities

- `svelte/reactivity`: `SvelteMap`, `SvelteSet`, `SvelteDate`, `SvelteURL`,
  `SvelteURLSearchParams` (reactive drop-ins — plain `Map`/`Set` in `$state`
  are NOT reactive on method calls), `MediaQuery` (≥5.7, careful with SSR),
  `createSubscriber` (bridge external event sources into reactivity).
- `svelte/reactivity/window`: reactive `scrollY`, `innerWidth`, etc.

## Context

- `createContext<T>()` (≥5.40) returns typed `[get, set]` pair — prefer it.
  Older API: `setContext(key, value)` / `getContext(key)`.
- Must be called during component init — not in effects, not after `await`.
- Context values are not reactive by themselves; pass a `$state` object.

## Async Svelte (`await` in components) — experimental

Enable in `svelte.config.js` (default in Svelte 6, flag then removed):

```js
export default { compilerOptions: { experimental: { async: true } } };
```

- `await` becomes legal in `<script>` top level, `$derived`, and markup.
- Requires an enclosing `<svelte:boundary>` with a `pending` snippet:

```svelte
<svelte:boundary>
  <p>{await fetchTotal()}</p>
  {#snippet pending()}<p>loading…</p>{/snippet}
  {#snippet failed(error, reset)}
    <button onclick={reset}>oops, retry</button>
  {/snippet}
</svelte:boundary>
```

- `pending` shows only for the first render; subsequent updates keep the old
  UI (check `$effect.pending()` for spinners).
- Independent `await` expressions in markup run **in parallel**.
- **Reactivity-loss trap**: in `$derived(await a + b)`-style code, state read
  after an `await` inside a plain async helper may not be tracked
  (`await_reactivity_loss` warning). Read state before awaiting, or keep
  reads in the derived expression itself.
- `hydratable(key, fn)` (from `svelte`) serializes server-computed values so
  the client doesn't recompute during hydration; keys must be unique.

## Pitfall grab-bag

- `let x = 'plain'` reassigned later and used in the template does **not**
  update — the compiler warns (`non_reactive_update`). Use `$state`.
- `(obj.array ??= []).push(...)` pushes to the pre-proxy array and loses the
  write — split into two statements.
- Reading `$state` in module scope of a `.svelte.js` captures the value once;
  read it inside functions/deriveds.
- `ontouchstart`/`ontouchmove` handlers are passive; use `on()` from
  `svelte/events` if you must `preventDefault`.
