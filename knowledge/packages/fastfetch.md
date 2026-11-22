---
type: Sub-flake
title: fastfetch
description: 'fastfetch — nixpkgs'' fastfetch wrapped with a build-time logo and a kitten shim that makes the kitty-icat logo draw in Herdr panes, plus one module for NixOS and nix-darwin; the root''s fastfetch twins re-export the module and install its finalPackage.'
resource: flakes/fastfetch/
tags: [sub-flake, package]
generated: { by: claude-code/fable-5-2, at: 2026-11-21T13:34:57-08:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/fastfetch/README.md
    title: 'flakes/fastfetch/README.md (outputs, why the shim, the module, the tests)'
  - id: fastfetch-manual
    resource: ../../docs/fastfetch.md
    title: 'docs/fastfetch.md (which terminals draw the logo, and how that was tested)'
---

Everything Nix about fastfetch in this repo: the wrapper, the `kitten` shim
and the module. Until 2026-11-21 these were two files in `lib/` and a pair of
option declarations in the module twins.

Consumed by the root flake as a relative-path input — see the
[sub-flake extraction pattern](../patterns/subflake-extraction.md).

- **The module wraps the host's `pkgs.fastfetch`, not this flake's
  package.** `module.nix` calls `pkgs.callPackage ./package.nix`, so the
  fastfetch underneath is the host's own, and on nebula that is
  snowglobe-factory's. `packages.fastfetch` (no logo chosen) exists for
  `nix run` and the root's re-export; no host installs
  it.[^subflake-readme]
- **The module installs nothing and declares no `enable` or `package`.**
  snowglobe-factory owns those names under `programs.fastfetch` on nebula.
  The [module twins](../modules/fastfetch.md) do the installing: its
  `package` option on NixOS, `environment.systemPackages` on the macs.
- **One module file serves both OSes**, exported as `nixosModules.fastfetch`
  and `darwinModules.fastfetch`. Nothing in it is OS-specific.
- **kitten is not in here.** The shim runs the next `kitten` on PATH, so
  [kitten](kitten.md) stays a plain package that nebula installs
  ([why the shim exists](../decisions/fastfetch-kitten-shim.md)).
- **The images and `config.jsonc` are not in here either.** They are the
  `home/fastfetch` [stow package](../patterns/stow-tree.md).

The move changed one thing in the built wrapper: `meta.mainProgram`, which
puts `NIX_MAIN_PROGRAM=fastfetch` in the derivation so `nix run` works. With
the shim text held the same, the old and new wrapper derivations for nebula
differed by that variable alone.

`checks.kitten-shim` runs the shim against a stand-in kitten and, on Linux,
three `script(1)` terminals. Its first run found a hang: against a terminal
that never answers the size query the shim waited for ever
([manual](../../docs/fastfetch.md), "Learned behaviours").[^fastfetch-manual]
The root's `nix flake check` doesn't run a sub-flake's checks; run
`nix flake check ./flakes/fastfetch` after touching the shim.

## Source

- Flake: [`flakes/fastfetch/`](../../flakes/fastfetch/)
- README: [`flakes/fastfetch/README.md`](../../flakes/fastfetch/README.md)

[^subflake-readme]: `flakes/fastfetch/README.md`: "Outputs", "Why the shim", "The module" and "Tests"
[^fastfetch-manual]: `docs/fastfetch.md`: "Inside Herdr" and the 2026-11-21 entries under "Learned behaviours & workarounds"
