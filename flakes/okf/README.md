# okf

CLI for maintaining an [OKF v0.1](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
knowledge bundle: `scaffold` stubs catalog docs from the repo sources, `index`
regenerates progressive-disclosure `index.md` listings, `validate` checks
spec/profile conformance and links, and `viz` renders the bundle as a
self-contained interactive 3D graph (single offline HTML file — Svelte 5 viewer
around Three.js glow spheres, bundled at generation time by `Bun.build`).

okf operates on a **workspace**: the nearest directory at or above cwd holding
an `okf.toml`, else the git toplevel (zero-config mode). `okf init [--dir=<d>]`
bootstraps a fresh workspace — a commented starter `okf.toml` plus the bundle
skeleton (`<d>/index.md`, `<d>/log.md`); it never overwrites. **Git is optional** —
`[vcs] provider = "auto"|"git"|"none"` selects the version-control adapter
(auto = git when the root is a git toplevel); the `none` provider walks the
filesystem (minus `[vcs] ignore` globs), stamps mtime dates, and skips commit
links, so any directory tree — no VCS at all — can host a bundle.

All commands read that one optional config file (strict-validated; malformed
config fails the command): `[bundle] dir` sets the bundle root (default
`knowledge/`), `[profile]` tunes validation policy (`required-fields`,
`recommended-fields`, `reserved-files`, `rooted-links = "error"|"allow"`,
`repo-links = "check"|"ignore"|"forbid"` — defaults reproduce the stock
OKF-plus-reference-tooling behavior), `[vcs]` adds `url` and
`commit-url-template = "{url}/commit/{hash}"` for forge-agnostic revision
links, and the remaining sections drive the viz viewer. Facet filter lenses
can classify concepts via `[facet.<name>.classify]` — the built-in
`nix-optional-attrs` parser or `provider = "command"` running any repo
script that prints a JSON name→value map.

`okf scaffold` runs the workspace's own metadata pass: `[scaffold] script`
(a TS/JS module dynamically imported; its default export receives the
injected `ScaffoldContext` API from `scaffold-api.ts` — emit with
idempotence/`--force`, VCS timestamps, comment extraction, text helpers) or
`command` (any argv, `OKF_*` env), plus declarative `[[scaffold.collect]]`
entries (glob + templates with `{name}`/`{Title}`/`{path}`/… placeholders,
validated at load) for repos with simple needs. It is a bun/TypeScript
project run from source — no compile step.

## Outputs

- `packages.<system>.okf` (= `default`) — the CLI: sources + vendored
  `node_modules` in the store, wrapped as `bin/okf` (`bun run --prefer-offline
  --no-install …` with git on PATH). Systems: `aarch64-darwin`, `aarch64-linux`,
  `x86_64-linux`.
- `checks.<system>.test` — the viewer unit tests (`bun test`) run offline
  against the vendored deps.
- `devShells.<system>.default` — bun + git for hacking on okf standalone.

## Consuming from a parent flake

While in-tree, the parent consumes it as a relative-path input — edits flow
through on the next evaluation, no lock bump needed:

```nix
inputs.okf = {
  url = "./flakes/okf";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-parts.follows = "flake-parts";
};
```

then re-export `inputs.okf.packages.${system}.okf` from the parent's packages
module. `follows` makes the parent build against the parent's nixpkgs; the
lock here only governs standalone builds (`nix build ./flakes/okf#okf`), so
drv paths may legitimately differ between the two. Promoting okf to its own
repository is a one-line swap to `github:owner/okf` — consumers change
nothing else.

## Adopting okf in any repo (no Nix required)

okf is plain bun — copy or clone this directory anywhere (or vendor it), then:

```sh
cd path/to/okf && bun install    # once; vendors the viz viewer deps
cd ~/src/your-project
bun path/to/okf/okf.ts init      # starter okf.toml + bundle skeleton
bun path/to/okf/okf.ts validate && bun path/to/okf/okf.ts viz
```

Any language, any domain, git or no VCS at all (`[vcs] provider = "none"`).
Wire your own metadata pass via `[scaffold]` (script with the injected
`ScaffoldContext` API, any-language `command`, or declarative
`[[scaffold.collect]]` globs).

## Dependency vendoring (the FOD hash)

`node_modules` is a fixed-output derivation running `bun install
--frozen-lockfile` (no bun packaging helper exists in nixpkgs; this mirrors its
`opencode`/`helix-gpt` packages). The lock is pure JS with no os/cpu-conditional
packages, so **one hash serves all platforms**. When `bun.lock` changes (or a
nixpkgs bump changes bun and the install layout shifts — the failure is a loud
hash mismatch), refresh it:

1. In `package.nix`, set the FOD's `outputHash = lib.fakeHash;`
2. `nix build ./flakes/okf#okf.node_modules` — copy the `got:` sha256 back in.

## Development

A parent repo's dev shell may provide `okf` as an impure wrapper over this
working tree (this repo does, via its dev module) — edits are live, no
rebuild. Standalone:

```sh
nix develop ./flakes/okf   # or rely on the parent dev shell's bun
bun install
bun test
bun okf.ts help
```

**Dev-tree only** (not available from the nix-built package, whose
`node_modules` is a read-only store path):

- `okf viz --check` — spawns `bunx svelte-check`, which writes
  `node_modules/.svelte2tsx-language-server-files` at startup.
- `okf viz --perf` — needs a locally installed Chrome (puppeteer-core).
