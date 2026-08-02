# Agent Guidelines — pkgs/

Custom package derivations: one file per package, `pkgs/<name>.nix` (or
`<name>/package.nix` when bundling adjacent files), kebab-case names. Nothing
here is auto-discovered — a derivation only becomes a flake output once
registered in `modules/packages.nix`
(`pkgs.callPackage ../pkgs/<name>.nix { }` under `perSystem.packages`, behind
a `lib.optionalAttrs` platform guard if it only builds on one OS). Full
walkthrough: "Adding a Custom Package" in `modules/AGENTS.md`.

Local conventions:

- **Shell tools:** the implementation lives in a companion `<name>.sh` (plain
  bash) wrapped by `writeShellApplication` in `<name>.nix` — runtime deps
  pinned, ShellCheck at build time (see `cbissue.nix` + `cbissue.sh`).
  Exception: `op` (1Password CLI) is never pinned — it must resolve from the
  ambient PATH to the system's wrapped, desktop-integrated binary.
- **Sources from flake inputs** are handed in as `callPackage` args rather
  than fetched in the derivation (see `tomato` in `modules/packages.nix`).
- **Reaching hosts:** a thin overlay in `overlays/<name>.nix` surfaces the
  derivation onto `pkgs` — register it in `modules/overlays.nix` (see
  `overlays/AGENTS.md`).
- **Unfree:** add an `allowUnfreePredicate` entry in
  `modules/darwin/core.nix`.
- **Outgrowing a plain derivation** (forked/patched source,
  standalone-buildable, future own repo)? Make it a sub-flake under `flakes/`
  instead (see `flakes/AGENTS.md`).
- **Catalog:** every package has a doc in `knowledge/packages/` — run
  `okf scaffold` + `okf index` after adding one (knowledge-bundle procedure).
