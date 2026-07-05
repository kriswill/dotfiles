# okf

CLI for maintaining an [OKF v0.1](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
knowledge bundle: `scaffold` stubs catalog docs from the repo sources, `index`
regenerates progressive-disclosure `index.md` listings, `validate` checks
spec/profile conformance and links, and `viz` renders the bundle as a
self-contained interactive 3D graph (single offline HTML file — Svelte 5 viewer
around Three.js glow spheres, bundled at generation time by `Bun.build`).

okf operates on the git repository containing the **current working directory**
(`git rev-parse --show-toplevel`). All commands read one optional config file,
`<repo>/okf.toml` (strict-validated; malformed config fails the command):
`[bundle] dir` sets the bundle root (default `knowledge/`), `[profile]` tunes
validation policy (`required-fields`, `recommended-fields`, `reserved-files`,
`rooted-links = "error"|"allow"`, `repo-links = "check"|"ignore"|"forbid"` —
defaults reproduce the stock OKF-plus-reference-tooling behavior), and the
remaining sections drive the viz viewer. It is a bun/TypeScript project run
from source — no compile step.

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

then re-export `inputs.okf.packages.${system}.okf` (see `modules/packages.nix`).
`follows` makes the parent build against the parent's nixpkgs; the lock here
only governs standalone builds (`nix build ./flakes/okf#okf`), so drv paths may
legitimately differ between the two. Promoting okf to its own repository is a
one-line swap to `github:owner/okf` — consumers change nothing else.

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

The dotfiles dev shell provides `okf` as an impure wrapper over this working
tree (`modules/dev.nix`) — edits are live, no rebuild. Standalone:

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
