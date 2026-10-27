---
type: Sub-flake
title: replace-dependencies
description: 'Sub-flake with a patched copy of nixpkgs'' replaceDirectDependencies (the rewriter behind replaceDependencies and system.replaceDependencies) that rewrites compiler-garbled store paths, rewrites directories without unsorting their NAR, and declares package identity for vulnerability scanners; exposed as an overlay and NixOS module, with regression checks, and used by nebula''s brotli graft.'
resource: flakes/replace-dependencies/
tags: [sub-flake, build-support, replace-dependencies]
generated: { by: claude-code/opus-5.5, at: 2026-10-26T19:40:00-07:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/replace-dependencies/README.md
    title: 'flakes/replace-dependencies/README.md (the three fixes, use, identity rules, checks)'
  - id: nixpkgs-rdd
    resource: https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/replace-direct-dependencies.nix
    title: 'nixpkgs replace-direct-dependencies.nix (the stock function)'
  - id: nixpkgs-579409
    resource: https://github.com/NixOS/nixpkgs/pull/579409
    title: 'nixpkgs #579409: replaceDirectDependencies: try rewriting with more effort (open)'
---

A drop-in replacement for nixpkgs' `replaceDirectDependencies`, the function
that `replaceDependencies` and NixOS's `system.replaceDependencies` call for
every store path they rewrite.[^nixpkgs-rdd] It started as a file inside
[brotli-graft](../modules/brotli-graft.md). It became a sub-flake so it can be
shared: unlike most of `flakes/`, it's a build helper rather than a package,
so it exposes `overlays.default`, `nixosModules.default` (which only adds the
overlay) and `checks` instead of `packages`.[^subflake-readme]

It fixes three problems the brotli swap ran into on
[nebula](../hosts/nebula.md):
- **Garbled store paths:** it also rewrites a bare hash when the old and new
  names match, which is nixpkgs PR #579409.[^nixpkgs-579409]
- **Unsorted archives:** it rewrites directories on the filesystem rather
  than as a NAR stream, so renamed entries can't unsort it.
- **Lost package identity:** it declares the `pname`, `version` and PyPI
  marker a name implies, for [nixploit](nixploit.md).

Why each was needed, and the numbers, are in the
[brotli-graft decision](../decisions/brotli-graft.md).

Each problem has a check that fails with the stock function and passes with
this one. A fourth check, `rename-collision`, covers a bug an independent
review found before publishing: a rename onto an existing entry made `mv`
move one directory into the other and the build succeed. It now fails
loudly, as the NAR stream did. The same review prompted three more changes:
- **Fixtures:** gained a nested rename and a relative link to a directory,
  and each check also fails against a copy of the rewriter with just its fix
  removed.
- **Faster symlink retargeting:** symlinks are now retargeted in parallel,
  which brought a 40,000-symlink tree from 35 s to 11 s (stock: 2 s).
- **Identity rules:** the output-suffix list grew (`lib32`, `modules`,
  `terminfo`, `login`, …), and config-file names stay undeclared.

On 2026-10-26 the checks built on x86_64-linux and evaluated on
aarch64-linux and aarch64-darwin. x86_64-darwin isn't advertised, since
nixpkgs 26.11 dropped it.

Consumption doesn't follow the usual `modules/packages.nix` re-export. The
only consumer, brotli-graft, applies `overlays.default` inside its own
version-guarded overlay, so the patched rewriter is active only while the
graft is. The move itself left nebula's system output path unchanged
(`zcfvp3kc…`, generation 193). The review fixes changed the rewrite steps, and
the rebuilt system still matched the no-swap baseline in `nixploit inventory`
(66 unversioned each, same small differences).

Consumed by the root flake as a relative-path input — see the
[sub-flake extraction pattern](../patterns/subflake-extraction.md).

## Source

- Flake: [`flakes/replace-dependencies/`](../../flakes/replace-dependencies/)
- README: [`flakes/replace-dependencies/README.md`](../../flakes/replace-dependencies/README.md)

[^subflake-readme]: flakes/replace-dependencies/README.md (the three fixes, use, identity rules, checks)
[^nixpkgs-rdd]: nixpkgs replace-direct-dependencies.nix (the stock function)
[^nixpkgs-579409]: nixpkgs #579409: replaceDirectDependencies: try rewriting with more effort (open)
