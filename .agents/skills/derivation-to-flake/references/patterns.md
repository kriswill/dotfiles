# derivation-to-flake — patterns, semantics, troubleshooting

Deep reference for the relative-path sub-flake pattern. Read this when something in the main
procedure is unclear or a verification step behaves unexpectedly.

## Why a relative-path input

`inputs.<name>.url = "./flakes/<name>";` is the key choice. On Nix ≥ 2.26 (verified on Determinate
Nix 2.34) a relative path input is resolved against the parent flake and, when both live in the same
git repo, is served from the **same source tree**. The lock entry is portable — no absolute paths,
no pinned rev:

```json
"<name>": { "locked": { "path": "./flakes/<name>", "type": "path" }, "original": { ... } }
```

Consequences worth internalizing:

- **Auto-pickup.** Because there's no pinned rev/narHash, the parent re-reads the sub-flake's source
  on every evaluation. Edits under `flakes/<name>/` take effect on the next `nix build` /
  `darwin-rebuild switch` with no lock bump. `nix flake update <name>` is a **no-op** for a path
  input (empirically: the lock file is byte-identical before/after).
- **`follows` overrides the sub-flake's own lock.** With
  `inputs.<name>.inputs.nixpkgs.follows = "nixpkgs"`, the parent builds `<name>` against the
  **parent's** nixpkgs. The sub-flake's own `flake.lock` then only governs *standalone* builds
  (`nix build ./flakes/<name>#...`). This is why you commit the sub-flake's lock (reproducible
  standalone builds) even though the parent ignores it.
- **Extraction is a URL swap.** Move `flakes/<name>/` to its own repo and change the input to
  `github:owner/<name>`. Consumers (`inputs.<name>.packages...`) are unchanged. *After* the swap,
  `nix flake update <name>` becomes meaningful — it advances the pinned rev.

Alternative forms `path:./flakes/<name>` and `path:flakes/<name>` also work, but they copy the subdir
as a standalone path source rather than sharing the git tree. Prefer the bare relative form for the
clean extraction story.

## Git-tracking is mandatory

A flake only sees git-tracked files in its source tree. An untracked `flakes/<name>/flake.nix`
fails to evaluate (`error: ... does not exist`). `scaffold.ts` `git add`s for you; if you create or
move files by hand, `git add` them before any `nix` command. (A `git worktree` created from `HEAD`
won't contain uncommitted files either — relevant when testing in isolation.)

## drv parity (what `verify.ts` reports)

`verify.ts` builds the sub-flake standalone and the root's re-exported output, then compares
`drvPath`s:

- **Equal** — the sub-flake's own lock happens to resolve to the same nixpkgs closure as the root.
  Common when both track `nixpkgs-unstable` and the relevant packages didn't change between revs.
- **Not equal** — expected and fine. The standalone build uses the sub-flake's pinned nixpkgs; the
  root build uses the root's (via `follows`). Different nixpkgs → different `stdenv`/toolchain →
  different derivation. This is **not** a failure; it's the whole point of `follows`. The hard
  signals are: standalone builds, root builds, `nix flake check` passes, no stale refs.

## Re-exporting across systems

flake-parts `perSystem` only emits outputs for the systems in the **root** `systems` list. If the
root is `[ "aarch64-darwin" ]` but the sub-flake builds three systems, re-export the extras directly:

```nix
flake.packages = builtins.listToAttrs (map (system: {
  name = system;
  value.<name> = inputs.<name>.packages.${system}.<name>;
}) [ "aarch64-linux" "x86_64-linux" ]);
```

This merges cleanly with the perSystem-generated `flake.packages.<darwin>` (different system keys, or
different attr keys under the same system). Note `nix flake check` on a single-platform machine
**omits** incompatible systems, so a broken Linux re-export won't surface there — check it explicitly
with `nix eval .#packages.x86_64-linux.<name>.drvPath` (or trust `verify.ts`, which evals each).

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `error: ... flakes/<name> does not exist` (or input not found) | sub-flake files not git-tracked | `git add flakes/<name>` |
| `error: attribute '<system>' missing` evaluating a re-export | the sub-flake doesn't expose that system | add it to the sub-flake's `systems`, or drop it from the re-export list |
| duplicate nixpkgs / version skew in the closure | missing `follows` | add `inputs.<name>.inputs.{nixpkgs,flake-parts}.follows` |
| overlay can't reference `inputs` | overlay imported from a separate file | define the overlay inline in `modules/overlays.nix` (it receives `inputs`) |
| `nix flake update <name>` seems to do nothing | it's a relative path input (no rev to bump) | expected — edits are picked up automatically; `update` only matters after a `github:` swap |
| build fails only in the sub-flake, not the old in-tree build | the sub-flake's fresh lock pulled a newer nixpkgs | `nix flake lock --update-input nixpkgs` in the sub-flake, or pin it; for the parent, `follows` already insulates it |
| stale `pkgs/<name>` / `overlays/<name>` references remain | consumer not repointed, or original not deleted | `git grep <name>`, repoint, `git rm` the originals |

## Worked example: `flakes/ccglass`

The pattern was first applied to `ccglass` (a forked/patched npm package compiled with
`bun build --compile`). End state:

- `flakes/ccglass/` — `flake.nix` (flake-parts, 3 systems) + `package.nix` + `fork.patch` + `README.md`
  + its own `flake.lock`.
- Root `flake.nix` — `inputs.ccglass.url = "./flakes/ccglass"` with nixpkgs/flake-parts `follows`.
- `modules/packages.nix` — `ccglass = inputs.ccglass.packages.${system}.ccglass;` (perSystem) plus the
  two-Linux-system `flake.packages` block.
- `modules/overlays.nix` — inline `ccglass = _final: prev: { ccglass = inputs.ccglass.packages.${prev.stdenv.hostPlatform.system}.ccglass; };`.
- `pkgs/ccglass/` and `overlays/ccglass.nix` removed.

`verify.ts ccglass` is green: standalone build, root build (same drv here), `nix flake check`, no
stale refs. Its dedicated maintenance skill (`patch-ccglass`) builds the sub-flake directly. That
extraction is the reference implementation for everything above.
