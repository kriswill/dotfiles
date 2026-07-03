# SvelteKit

The app framework (routing, SSR, data loading, deployment) around Svelte.
Verified against SvelteKit 2.69 docs, 2026-07-02. Component-level syntax:
[manual.md](manual.md) / [runes.md](runes.md).

## Project layout

```text
src/
├ lib/               # import as $lib/...
│ └ server/          # server-only ($lib/server/...) — client import = build error
├ params/            # param matchers
├ routes/            # filesystem router
├ hooks.server.js    # handle, handleFetch, handleError, init
├ hooks.client.js    # handleError, init
├ hooks.js           # universal: reroute, transport
├ app.html           # %sveltekit.head% / %sveltekit.body%
└ service-worker.js
svelte.config.js     # adapter, compilerOptions, kit.*
vite.config.js       # sveltekit() plugin
```

## Routing

Directory = route; special files start with `+`:

| File | Role |
| --- | --- |
| `+page.svelte` | Page component; gets `data` (and `form`) via `$props()` |
| `+page.js` | `load` running on server **and** client (universal) |
| `+page.server.js` | Server-only `load` + form `actions` |
| `+layout.svelte` | Wraps children: `{@render children()}`; own `load` via `+layout(.server).js` |
| `+server.js` | API endpoint: `export function GET/POST/...(event)` → `Response`; `json()` helper |
| `+error.svelte` | Error page for the subtree; reads `page.error` / `page.status` |

Dynamic segments: `[slug]`, rest `[...path]`, optional `[[lang]]`,
matchers `[id=integer]` → `src/params/integer.js` exporting `match(value)`.
Route groups `(app)/` organize without affecting URLs; `+page@(app).svelte`
breaks out of layout nesting.

## Load functions

```js
// +page.server.js — server-only: db, private env, cookies
export async function load({ params, cookies, fetch, parent, depends, setHeaders, untrack }) {
  return { post: await db.getPost(params.slug) };  // must be serializable
}
```

```svelte
<!-- +page.svelte -->
<script>
  /** @type {import('./$types').PageProps} */   // PageProps/LayoutProps ≥2.16
  let { data } = $props();
</script>
```

- **Universal (`+page.js`) vs server (`+page.server.js`)**: universal runs on
  both sides and may return anything (classes, components); server runs
  server-only and must return serializable data (devalue: Date/Map/BigInt ok).
  Both defined → server result feeds universal's `data` argument.
- Use the provided `fetch` — inherits cookies/headers, relative URLs work
  server-side, and responses are inlined into HTML for hydration.
- `parent()` awaits parent layout data; `depends('app:key')` +
  `invalidate('app:key')` / `invalidateAll()` for manual reruns;
  `untrack(() => url.pathname)` to opt out of dependency tracking.
- Layout `load` doesn't rerun on child navigation unless its deps changed.
- **Streaming**: server `load` can return nested promise properties — page
  renders immediately, promises stream in; `{#await data.comments}` in the page.

## `$app/state` (≥2.12; replaces `$app/stores`)

```svelte
<script>
  import { page, navigating, updated } from '$app/state';
</script>
<title>{page.data.title}</title>       <!-- fine-grained reactive, no $ prefix -->
```

`page` (url, params, data, form, error, status), `navigating`, `updated`.
Old `$app/stores` (`$page`) is the legacy equivalent.

## Form actions (`+page.server.js`)

```js
import { fail, redirect } from '@sveltejs/kit';

export const actions = {
  default: async ({ request, cookies }) => {
    const data = await request.formData();
    if (!data.get('email')) return fail(400, { email: 'required' });  // → `form` prop
    redirect(303, '/dashboard');
  },
  // named: <form action="?/named">; invoke as login, register, ...
};
```

```svelte
<script>
  import { enhance } from '$app/forms';
  let { form } = $props();               // last action's return / fail payload
</script>
<form method="POST" use:enhance>...</form>
```

- Works without JS; `use:enhance` progressively enhances (no reload).
- Custom enhance: `use:enhance={({ formData, cancel }) => async ({ result, update }) => {...}}`.
- `fail(status, data)` for validation errors; `redirect`/`error` same as load.

## Remote functions (≥2.27, experimental)

Type-safe client↔server RPC; enable `kit: { experimental: { remoteFunctions: true } }`.
Declared in `.remote.js`/`.remote.ts` files; callable from anywhere, run on server.

```js
// data.remote.js
import { query, command, form, prerender } from '$app/server';
import * as v from 'valibot';                       // any Standard Schema lib

export const getPosts = query(async () => db.getPosts());
export const addPost = command(v.object({ title: v.string() }),
  async ({ title }) => db.insert(title));
```

`query` (read), `command` (write), `form` (progressively-enhanced forms,
`.for(id)` for per-item instances), `prerender` (build-time). Refresh with
`getPosts().refresh()`; single-flight mutations via `command().updates(query)`.

## Hooks

- `hooks.server.js` — `handle({ event, resolve })` (middleware: auth,
  `event.locals`, rewriting; compose with `sequence()` from
  `@sveltejs/kit/hooks`), `handleFetch` (rewrite server-side `fetch`),
  `handleError` (report unexpected errors; shape `page.error`), `init`.
- `hooks.js` (universal) — `reroute` (URL → route translation, i18n paths),
  `transport` (custom types across the server/client boundary).

## Errors & redirects

```js
import { error, redirect } from '@sveltejs/kit';
error(404, 'Not found');       // expected: renders nearest +error.svelte
redirect(303, '/login');       // don't call inside try {} — it throws internally
```

Kit 2: you call them, you do **not** `throw` them yourself. Unexpected
(thrown) errors → `handleError` hook, message hidden as "Internal Error".

## Env & server-only modules

| Module | Read at | Visibility |
| --- | --- | --- |
| `$env/static/private` | build | server only |
| `$env/static/public` | build | anywhere; `PUBLIC_` prefix |
| `$env/dynamic/private` | runtime | server only |
| `$env/dynamic/public` | runtime | anywhere; `PUBLIC_` prefix |

Static values are dead-code-eliminated; dynamic values can't be read during
prerendering. `$lib/server/*` and `*.server.js` modules can never be imported
into client code — Kit fails the build, tracing the import chain.

## Page options (export from `+page(.server).js` / `+layout(.server).js`)

```js
export const prerender = true;   // or false | 'auto'
export const ssr = true;         // false → client-only (SPA-style) page
export const csr = true;         // false → zero JS shipped
export const trailingSlash = 'never';  // 'always' | 'ignore'
export const entries = () => [{ slug: 'a' }];  // seed dynamic prerender routes
```

## Adapters (`svelte.config.js`)

`adapter-auto` (default; detects Vercel/Netlify/Cloudflare/...),
`adapter-node` (standalone Node server; `node build`), `adapter-static`
(full SSG — every route must be prerenderable; set
`export const prerender = true` in the root layout), plus platform adapters.

## Navigation API (`$app/navigation`)

`goto(url, { invalidateAll, replaceState, state })`, `invalidate`,
`invalidateAll`, `refreshAll`, `preloadData`, `preloadCode`,
`beforeNavigate`, `afterNavigate`, `onNavigate` (view transitions hook),
`pushState`/`replaceState` for **shallow routing** (`page.state`, e.g.
modal-over-list without a full navigation).

Link tuning via attributes: `data-sveltekit-preload-data="hover"`,
`data-sveltekit-reload`, `data-sveltekit-noscroll`, etc.

## Kit-2-isms worth remembering

- `cookies.set(name, value, { path })` — `path` is required.
- Top-level promises in `load` return values are no longer auto-awaited
  (only nested ones stream) — `await` what you need.
- `resolve(...)` from `$app/paths` builds route-id-safe hrefs.
- `use:enhance` callbacks: use `formData` (not removed `form`/`data`).
- `error`/`redirect` are called, not thrown (see above).
