---
name: patch-ccglass
description: Update or fix the ccglass Nix derivation for a new upstream release. Clone the latest upstream tag, scan the source for bun-compile hazards, write/test the fork patch, then build and verify the flake's ccglass package (binary + MCP + dashboard) on aarch64-darwin. Use when bumping ccglass, regenerating its patch, or troubleshooting its build.
---

# patch-ccglass

Maintains [`pkgs/ccglass`](pkgs/ccglass) — a `ccglass` derivation built into a single
standalone binary with `bun build --compile`. Because a compiled binary can't do the
script-relative disk reads upstream relies on, the package carries a **maintained fork**
([`pkgs/ccglass/fork.patch`](pkgs/ccglass/fork.patch)). On every upstream release that patch
must be re-checked, and the build re-verified.

The whole workflow is driven by **[`driver.ts`](.claude/skills/patch-ccglass/driver.ts)** (bun + TypeScript). Paths below are
relative to the repo root. **aarch64-darwin only** (the output is a Mach-O arm64 binary).

> Background on the three fork edits and the wiring is in
> [`pkgs/ccglass/README.md`](pkgs/ccglass/README.md). This skill is the *update procedure*.

## Prerequisites

`bun`, `nix`, and `git` — all already on PATH here (bun via the nix profile). No `apt-get`; this runs
on the user's macOS machine. The driver uses bun's `fetch`/`Bun.spawn` for the runtime checks, so no
`curl` is needed (and it sidesteps the context-mode curl hook).

## Run (agent path)

One command does clone + hazard scan + patch-check + build + all runtime checks:

```bash
bun .claude/skills/patch-ccglass/driver.ts all
```

Or step through it. **Check what the latest upstream tag is:**

```bash
bun .claude/skills/patch-ccglass/driver.ts latest-tag
```

**Clone it, scan for compile hazards, and test whether the current patch still applies:**

```bash
bun .claude/skills/patch-ccglass/driver.ts prepare
```

`prepare` greps the new source for the three known hazard classes (version read at load, `web/`
served from a computed path, MCP subprocess spawn) and reports each `file:line`, then runs
`git apply --check`. It prints `CLONE=<path>` — the checkout you'll edit if the patch needs redoing.
Pass an explicit tag to target a specific release: `… prepare v1.2.0`.

**Build the flake output and exercise the binary** (only meaningful if the patch applied):

```bash
bun .claude/skills/patch-ccglass/driver.ts verify
```

`verify` runs `nix build .#packages.aarch64-darwin.ccglass` (out-link under `$TMPDIR`, not the repo)
and then asserts all three patched behaviors:
- `ccglass --version` → prints the version (Edit A: didn't crash reading `../package.json`).
- `ccglass __mcp__` over stdio → `initialize` + `tools/list` return the 4 tools (Edits B/C).
- `ccglass run` dashboard → `/`, `/app.js`, `/style.css`, `/stream.css`, `/theme.js` all 200,
  `/nope.js` → 404 (Edit D: embedded web assets).

Expected tail of a green run:

```
== dashboard embedded assets (Edit D) ==
  /             -> 200 (1630 bytes)
  /app.js       -> 200 (58547 bytes)
  ...
  /nope.js      -> 404 (expected 404)
✓ all checks passed
```

## Re-authoring the patch (when `prepare` says it no longer applies)

The fork makes three edits. Re-apply them by hand in the `CLONE` dir `prepare` printed, then
regenerate and re-verify:

1. **`src/cli.js` — version.** Replace the `fs.readFileSync(… "package.json" …)` version read with a
   literal: `const VERSION = "<version>";`.
2. **`src/cli.js` — MCP spawn.** In `mcpArgs`, change `args: [path.join(__dirname, "mcp.js")]` to
   `args: ["__mcp__"]`, and at the very top of `main(argv)` add the sentinel route:
   `if (argv[0] === "__mcp__") { await import("./mcp.js"); return; }`.
3. **`src/server.js` — web assets.** Replace the `__dirname`-relative `WEB_DIR` read with bun
   `import … with { type: "file" }` embeds for the five `web/` files (`index.html`, `app.js`,
   `theme.js`, `style.css`, `stream.css`), preload them into a buffer cache, and serve `serveStatic`
   from that cache. (Copy the shape from the current `fork.patch`.)

Then:

```bash
bun .claude/skills/patch-ccglass/driver.ts regen-patch <CLONE>   # writes pkgs/ccglass/fork.patch
```

…and update `version` in [`pkgs/ccglass/package.nix`](pkgs/ccglass/package.nix) (and the
hardcoded `VERSION` in the patch) to the new version, then re-run `verify`.

## Troubleshooting (errors actually hit)

- **`build failed … hash mismatch`** — happens after a version/tag bump (the pinned `src.hash` /
  `npmDepsHash` no longer match). `verify` parses the error and prints the exact lines to paste, e.g.
  `set src.hash = "sha256-…";` and `set npmDepsHash = "sha256-…";`. Update
  [`pkgs/ccglass/package.nix`](pkgs/ccglass/package.nix) and re-run `verify`. (Set them to
  `lib.fakeHash` first if starting fresh; src mismatch surfaces before the npm-deps one.)
- **`fork.patch does NOT apply`** — upstream moved the lines. Re-author (above). `prepare`'s hazard
  scan tells you whether the targets still exist or changed shape.
- **A hazard scan line shows `(no match …)`** — upstream changed how that behavior works. Inspect
  that area in the clone; the fork may need a *different* edit, not just relocated context.

## Gotchas

- **The dashboard banner (`dashboard: http://127.0.0.1:<port>`) is on stderr, not stdout** — the
  driver reads stderr for the port. The MCP JSON-RPC is on stdout. Keep that split if you extend it.
- **Annotated-tag clone warning** (`refs/tags/vX … is not a commit!`) is harmless — git checks out the
  commit the tag points to.
- **The build out-link lives in `$TMPDIR/patch-ccglass/result`, not `./result`** — `verify` keeps the
  repo tree clean. The clone for `prepare` stays at `$TMPDIR/patch-ccglass/<tag>` for re-authoring.
- **`regen-patch` emits git's canonical diff** (single-space blank context lines), which may differ
  cosmetically from a hand-written patch. Both apply; prefer the regenerated form.
- **`regen-patch` refuses an empty diff** — if it says "clone has no changes," your edits didn't land
  in that clone (or you pointed it at the wrong dir).
