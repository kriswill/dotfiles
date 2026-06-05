---
name: derivation-to-flake
description: >-
  Extract an in-tree Nix package/derivation into its own flake-parts sub-flake (under
  flakes/<name>/) that the root flake consumes via a relative-path input — the stepping
  stone to later splitting it into a separate repo with a one-line URL swap. Use this skill
  whenever the user wants to modularize or split a Nix flake or reorganize packages:
  "turn this derivation into its own flake", "extract <pkg> into a sub-flake", "make <pkg>
  a standalone / in-repo flake", "split pkgs/<x> out", "prep <pkg> to move to its own repo",
  "modularize the flake", or is moving things from pkgs/ into flakes/. Covers the whole
  procedure end to end — scaffold, wire the root (relative-path input + follows), test
  (standalone build + parity + flake check), adversarial quality review, and documentation.
  Bundled bun/TypeScript scripts (inventory.ts, scaffold.ts, verify.ts) do the rote steps.
compatibility: Requires nix (flakes enabled), bun, and git. Assumes a flake-parts repo.
---

# derivation-to-flake

Extracts a package that currently lives in-tree (`pkgs/<name>.nix` or `pkgs/<name>/`) into a
**self-contained sub-flake** at `flakes/<name>/`, and rewires the root flake to consume it
through a **relative-path input**. One git tree still serves everything, but the package is now
independently buildable and lockable — so later promoting it to its own repository is just
changing `"./flakes/<name>"` → `"github:owner/<name>"`.

This is the repo's documented "Adding a Custom Package as a Sub-flake" pattern (see `AGENTS.md`).
Reach for it when a package warrants its own flake: it carries forked/patched source, you want it
standalone-buildable, or you intend to spin it out later. For a plain, tightly-coupled package
that will always live here, the in-tree `pkgs/<name>.nix` path is simpler — don't over-extract.

The rote, deterministic steps are bun scripts under `scripts/` (run them from anywhere inside the
repo — they walk up to `flake.nix`). The judgment-heavy steps (the root AST edits, the quality
review) stay with you, guided by what the scripts print.

## The procedure

### 1. Inventory — know what you're touching
```
bun .claude/skills/derivation-to-flake/scripts/inventory.ts <name>
```
Reports where the package is defined and **every** reference to it (the consumers you'll repoint:
typically `modules/packages.nix`, an `overlays/<name>.nix`, and any `pkgs.<name>` usage). Read this
before changing anything so nothing is missed.

### 2. Scaffold the sub-flake
```
bun .claude/skills/derivation-to-flake/scripts/scaffold.ts <name> [--from <path>] [--systems a,b,c]
```
Creates `flakes/<name>/` with a flake-parts `flake.nix` (exposing `packages.<system>.<name>` and
`packages.<system>.default`), copies the package files in (`pkgs/<name>.nix` → `package.nix`; a
directory is copied whole so patches/README come along), **`git add`s** them, and runs
`nix flake lock`. It then prints the exact root edits for the next step. It does **not** delete the
original or edit the root — those are deliberate, reviewed edits you make by hand.

Match `--systems` to the package's actual support: check its `meta.platforms` and pass only what it
builds. A darwin-only package (e.g. a prebuilt `*-darwin` binary) should be `--systems aarch64-darwin`
— otherwise the sub-flake advertises Linux outputs that fail to build (and `nix flake check` on a Mac
won't catch it, since it omits incompatible systems). The default covers darwin + the two common Linux.

> Why `git add` matters: Nix only sees git-tracked files in a flake's source tree. An untracked
> `flakes/<name>/flake.nix` evaluates to "does not exist". The scaffold tracks them for you; if you
> hand-create files, track them before building.

### 3. Test the sub-flake on its own
```
nix build ./flakes/<name>#<name>      # or .#packages.<system>.<name>
./result/bin/<binary> --version       # whatever proves it actually works
```
Confirm it builds and runs in isolation before wiring it into the root — that isolates "is the
sub-flake correct?" from "is the consumption correct?".

### 4. Wire the root flake (manual — these are AST edits)
The scaffold prints these tailored to `<name>`; the shape is:

- **`flake.nix`** — add the relative-path input. `follows` makes the parent build the package
  against the *parent's* nixpkgs (no second nixpkgs in the closure):
  ```nix
  <name> = {
    url = "./flakes/<name>";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-parts.follows = "flake-parts";
  };
  ```
- **`modules/packages.nix`** — re-export from the input instead of `callPackage` (perSystem needs
  the `system` arg). For systems outside the root's `systems` list, re-export via a `flake.packages`
  block:
  ```nix
  # in perSystem = { pkgs, system, ... }:
  <name> = inputs.<name>.packages.${system}.<name>;

  # for the extra systems the sub-flake builds but the root doesn't list:
  flake.packages = builtins.listToAttrs (map (system: {
    name = system;
    value.<name> = inputs.<name>.packages.${system}.<name>;
  }) [ "aarch64-linux" "x86_64-linux" ]);
  ```
- **`modules/overlays.nix`** — if a host needs `pkgs.<name>`, define the overlay **inline** here.
  Overlays are pure `final: prev:` functions and can't import `inputs`, so close over the module's
  `inputs` (and read the system off `prev`):
  ```nix
  { inputs, ... }:
  {
    flake.overlays.<name> = _final: prev: {
      <name> = inputs.<name>.packages.${prev.stdenv.hostPlatform.system}.<name>;
    };
  }
  ```
- **Remove the originals** once consumers are repointed: `git rm -r pkgs/<name>(.nix) overlays/<name>.nix`.
- **`nix flake lock`** to add the `<name>` input to the root `flake.lock`.

### 5. Verify the whole thing
```
bun .claude/skills/derivation-to-flake/scripts/verify.ts <name>
```
Builds the sub-flake standalone, builds the root's re-exported `.#packages.<system>.<name>` (proving
consumption), runs `nix flake check`, and scans for stale references to the old in-tree path. It
exits non-zero on any hard failure. A drv-parity note explains the expected outcome (see references).

### 6. Quality review — verify like an adversary
A green build doesn't mean it's right. Review (ideally with independent subagents / a workflow, each
defaulting to skeptical) across these dimensions, then confirm each finding:
- **Flake correctness** — sub-flake `flake.nix` is valid flake-parts; the root input + `follows` are
  correct; both `flake.lock`s are consistent (the `<name>` node is a relative path, nixpkgs/flake-parts
  follow the root — no duplicate nixpkgs).
- **Consumption integrity** — the overlay provides `pkgs.<name>` on every relevant system; the
  home-manager / host consumers resolve; **no dangling references** to the old `pkgs/<name>` or
  `overlays/<name>.nix` remain anywhere.
- **Docs & pattern** — the repo's guide (`AGENTS.md`/`CLAUDE.md`) still matches reality; the sub-flake
  README is accurate; the "swap to github later" story actually holds.

### 7. Document
- Give the sub-flake a `README.md` describing its outputs and how a parent consumes it (relative-path
  input + `follows`), so it reads correctly once it's a separate repo.
- Keep the repo's contributor guide truthful: if you removed the in-tree path and the overlay file,
  make sure `AGENTS.md`/`CLAUDE.md` documents the sub-flake pattern rather than a deleted file.

### 8. Use it / extract later
The relative-path input means the parent **picks up edits to the sub-flake automatically** on the
next evaluation — `nix flake update <name>` is a no-op until you swap the URL. When you're ready to
move it to its own repository: push `flakes/<name>/` somewhere and change the input URL to
`github:owner/<name>` (then `nix flake update <name>` becomes the way to advance the pin). Nothing
else about the consumers changes.

## Gotchas (the ones that bite)

- **Untracked = invisible.** `git add` the sub-flake before any `nix` command touches it.
- **Overlays can't see `inputs`.** Define the `<name>` overlay inline in `modules/overlays.nix`
  (which receives `inputs`); don't try to import a separate `overlays/<name>.nix` that needs them.
- **`follows`, not a second nixpkgs.** Without `inputs.<name>.inputs.nixpkgs.follows = "nixpkgs"`,
  you get a duplicate nixpkgs in the closure and possible version skew.
- **Root `systems` may be narrower than the sub-flake's.** The root's `perSystem` only covers its
  listed systems; re-export the rest with the `flake.packages` block, or those outputs won't exist.
- **`flake check` won't catch a broken cross-system re-export** on a single-platform repo — it omits
  incompatible systems. `verify.ts`/an explicit `nix eval .#packages.<linux>.<name>` will.
- **drv parity is informational.** The standalone sub-flake locks its own nixpkgs; the root build
  uses the root's (via `follows`). The two drvs are often equal but need not be — see references.

See [references/patterns.md](references/patterns.md) for the deep relative-path-input semantics, the
drv-parity explanation, troubleshooting, and the worked `flakes/ccglass` example.
