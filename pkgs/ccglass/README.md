# ccglass

A Nix derivation for [`ccglass`](https://github.com/jianshuo/ccglass) — a local logging
reverse-proxy + web dashboard that shows exactly what a coding agent (Claude Code, Codex,
DeepSeek, Reasonix, Kimi, …) sends to the model.

Upstream is a pure-ESM Node app published to npm. Here it is built into a **single standalone
executable** with `bun build --compile`, so nothing depends on a global `bun -g i ccglass`.

## Files

| File | Purpose |
| --- | --- |
| [`package.nix`](package.nix) | The derivation: `buildNpmPackage` for reproducible deps + `bun build --compile`. |
| [`fork.patch`](fork.patch) | Source patch required to survive compilation (see below). |

## How it builds

1. `buildNpmPackage` fetches the source from the `v<version>` GitHub tag and populates
   `node_modules` **offline** from the upstream `package-lock.json` (pinned by `npmDepsHash`).
   This runs in `configurePhase`, before our build.
2. `fork.patch` is applied (`patches = [ ./fork.patch ]`).
3. A custom `buildPhase` runs `bun build --compile ./bin/ccglass.js --outfile ccglass`, bundling
   the JS module graph + the three deps (`@modelcontextprotocol/sdk`, `cross-spawn`, `zod`) and the
   bun runtime into one ~64 MB Mach-O arm64 binary.
4. A custom `installPhase` installs only that binary to `$out/bin/ccglass`.

## Why the fork (`fork.patch`)

A compiled single-file binary cannot do the **script-relative disk reads** upstream relies on
(`bun build --compile` only embeds the statically-analyzable `import` graph, not computed `fs`
reads). The patch makes three behaviors survive compilation:

| Upstream behavior | Problem when compiled | Patch |
| --- | --- | --- |
| `src/cli.js` reads `../package.json` for the version **at module load** | File isn't on disk → crash on launch | Hardcode `const VERSION = "<version>"`. |
| `src/server.js` serves `web/` via `path.join(__dirname, "..", "web", file)` | Computed path → dashboard 404s | `import … with { type: "file" }` to embed the 5 web assets, served from an in-memory cache. |
| `src/cli.js` spawns the MCP server as `process.execPath` + `__dirname/mcp.js` | Can't re-exec an arbitrary `.js` | Self-exec sentinel: spawn `<ccglass> __mcp__`; `main()` routes it to `import("./mcp.js")`. |

This is a **maintained fork** — the patch is pinned to upstream's source shape and must be
re-checked on every version bump.

## How it's wired into the flake

- **Package output** — registered in [`modules/packages.nix`](../../modules/packages.nix):
  `ccglass = pkgs.callPackage ../pkgs/ccglass/package.nix { };`
  → build with `nix build .#packages.aarch64-darwin.ccglass`.
- **Overlay** — [`overlays/ccglass.nix`](../../overlays/ccglass.nix), registered in
  [`modules/overlays.nix`](../../modules/overlays.nix), so `pkgs.ccglass` is available to hosts.
- **Consumed by** the `claude-account-selector` home-manager module
  ([`default.nix`](../../modules/home-manager/claude-account-selector/default.nix)), which adds
  `pkgs.ccglass` to `home.packages`. Its `wrapper.zsh` invokes `command ccglass`, which now resolves
  to the Nix store binary instead of `~/.bun/bin/ccglass`.

## Updating to a new ccglass version

1. Bump `version` in [`package.nix`](package.nix).
2. Set `src.hash` and `npmDepsHash` to `lib.fakeHash`, run
   `nix build .#packages.aarch64-darwin.ccglass`, and copy the real `got:` hashes from the two
   build errors (src first, then npm-deps).
3. Re-confirm the patch still applies — fetch the new tag and
   `git apply --check -p1 pkgs/ccglass/fork.patch`. If it fails, re-apply the three edits above by
   hand against the new source and regenerate (`git diff > fork.patch`). Also bump the hardcoded
   `VERSION` string in the patch.
4. Re-run the regression checks below, then `darwin-rebuild switch --flake .`.

## Verifying a build

```sh
nix build .#packages.aarch64-darwin.ccglass

# Edit A — must not crash on launch:
./result/bin/ccglass --version            # -> 1.0.0

# Edit D — dashboard serves embedded assets (start live mode, then probe the port it prints):
./result/bin/ccglass run --no-open -- sleep 10
#   GET /  /app.js  /style.css  /stream.css  /theme.js  -> 200 ;  GET /nope.js -> 404

# Edits B/C — MCP stdio server initializes and lists tools:
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | ./result/bin/ccglass __mcp__
```
