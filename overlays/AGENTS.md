# Agent Guidelines — overlays/

Nixpkgs overlays, one per file, registered in `modules/overlays.nix`
(`flake.overlays.<name> = import ../overlays/<name>.nix;`). Every host on
both OSes applies the WHOLE set — an overlay that only makes sense on one OS
must be internally platform-guarded (see `podman.nix`) or only ADD lazy attrs
the other OS never evaluates.

Two shapes:

- **Thin re-export** — surfaces a `pkgs/` derivation onto `pkgs`:
  `_final: prev: { <name> = prev.callPackage ../pkgs/<name>.nix { }; }`
  (see `kitten.nix`; the derivation side is covered in `pkgs/AGENTS.md`).
- **Patch/wrapper overlay** — modifies or wraps an upstream package
  (`gh-op.nix`, `direnv.nix`). Start these with a header comment explaining
  WHY — the header is the file's documentation. A workaround expected to
  become unnecessary is flagged `TEMPORARY` at its registration in
  `modules/overlays.nix`, pointing at the file header.

Sub-flake packages (`flakes/`) do NOT get a file here — they get an inline
overlay directly in `modules/overlays.nix`, which receives `inputs` (see
`flakes/AGENTS.md`).

Related: `modules/AGENTS.md` (Nix style + wiring walkthroughs),
`pkgs/AGENTS.md`, `flakes/AGENTS.md`.
