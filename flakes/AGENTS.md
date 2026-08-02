# Agent Guidelines — flakes/

Self-contained sub-flakes consumed by the root flake via relative-path inputs
(`inputs.<name>.url = "./flakes/<name>";` + `follows` to dedupe
nixpkgs/flake-parts). This level is for a package that outgrows a plain
`pkgs/` derivation — forked/patched source, standalone-buildable, or destined
for its own repo (extraction = swapping the input URL to
`github:owner/<name>`). Full walkthrough: "Adding a Custom Package as a
Sub-flake" in `modules/AGENTS.md`.

Local conventions:

- Each `flakes/<name>/` uses flake-parts, exposes `packages.<system>.<name>`
  (+ `default`), owns its `flake.lock`, and carries a `README.md` explaining
  what it repackages and how (see `ccglass/`, `apple-container/`). Auxiliary
  files live beside it (fork patches, apple-container's `darwin-module.nix`).
- **`git add` everything** — untracked sub-flake files are invisible to nix.
- **Wiring happens in modules/**: re-export the package in
  `modules/packages.nix`; if hosts need it on `pkgs`, add an INLINE overlay
  in `modules/overlays.nix` (which receives `inputs`) — not a file in
  `overlays/` (see `overlays/AGENTS.md`).
- **Simpler package?** A plain derivation in `pkgs/` is the default level
  (see `pkgs/AGENTS.md`).
- **Catalog:** each sub-flake has a doc in `knowledge/packages/` — run
  `okf scaffold` + `okf index` after adding one (knowledge-bundle procedure).
