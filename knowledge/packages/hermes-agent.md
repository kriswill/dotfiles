---
type: Sub-flake
title: hermes-agent
description: 'Sub-flake that builds Nous Research''s Hermes Agent (the hermes CLI and its messaging/cron gateway) from a trimmed, path-rewritten copy of upstream''s nix/ against the v0.22.5 source, plus a single-owner services.hermes-agent NixOS module (wrapped CLI, 2750 state, herdr plugin option); enabled on nebula.'
resource: flakes/hermes-agent/
tags: [sub-flake, package, ai-agent]
generated: { by: claude-code/opus-5-5, at: 2026-10-30T03:00:00+00:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/hermes-agent/README.md
    title: 'flakes/hermes-agent/README.md (layout, outputs, module changes, bumping the tag)'
  - id: upstream-nix-v0-22-5
    resource: https://github.com/NousResearch/hermes-agent/tree/v0.22.5/nix
    title: 'Upstream nix/ at the pinned tag (the files the copy started from)'
  - id: patchelf-674
    resource: https://github.com/NixOS/patchelf/issues/674
    title: 'NixOS/patchelf#674: setting interpreter before rpath results in broken binary'
---

The source is upstream's. The packaging and the module are ours, copied from
upstream's `nix/` at the tag and kept under upstream's file names, so that
`nixfmt < <upstream>/nix/<file> | diff - nix/<file>` shows only our changes.
Each changed file explains itself in a comment marked
`Ours:`.[^subflake-readme] Why vendor rather than consume upstream's flake:
[hermes-agent-vendored-nix](../decisions/hermes-agent-vendored-nix.md).

- **The source is a `flake = false` input**, `hermes-agent-src`, at
  `v0.22.5`. `nix/packages.nix` turns it into `hermesSrc`, a path value at its
  root, and a `lib.makeScope` hands it to every `callPackage`. Upstream's
  `../x` becomes `hermesSrc + "/x"`. It has to be a path: `lib.fileset`
  rejects strings, and copying a path is what reproduces upstream's filtered
  store paths. With `version` reset to `0.0.0`, the package is
  drv-identical to upstream's own `packages.x86_64-linux.default`
  (`zfdxw3zg…`).
- **Outputs.** `packages.<system>.hermes-agent` (and `default`) is upstream's
  `full` package with `version` set to the tag. Upstream leaves it at
  `0.0.0`, so `hermes --version` printed `v0.0.0`. `nixosModules.default` is
  the module. The root re-exports the package in `modules/packages.nix` and
  the module as [hermes-agent](../modules/hermes-agent.md).
- **Dropped:** the desktop app (Electron), the dev shell, home-manager, the
  checks suite, the overlay, the sandbox, the per-tool `pm-*` packages, and
  `update-npm-lockfile`, which was the only user of the `npm-lockfile-fix`
  input. Container mode is gone from the module.
- **No nixpkgs follow.** The other inputs (nixpkgs, pyproject-nix, uv2nix,
  pyproject-build-systems) are locked to the revs in the tag's own
  `flake.lock`. The package autopatchelfs a prebuilt node, and the
  patchelf 0.19.2 in the root's nixpkgs corrupts it,[^patchelf-674] so node
  segfaults during the TUI build. The root's input therefore follows only
  flake-parts.
- **Bumping** means reading upstream's `nix/` diff between tags, porting it
  into the copies, re-locking those inputs to the new tag's lock, and
  re-checking parity.[^upstream-nix-v0-22-5]

Enabled on [nebula](../hosts/nebula.md) by
[nebula-hermes-agent](../modules/nebula-hermes-agent.md). Consumed by the
root flake as a relative-path input. See the
[sub-flake extraction pattern](../patterns/subflake-extraction.md).

## Source

- Flake: [`flakes/hermes-agent/`](../../flakes/hermes-agent/)
- README: [`flakes/hermes-agent/README.md`](../../flakes/hermes-agent/README.md)

[^subflake-readme]: flakes/hermes-agent/README.md
[^upstream-nix-v0-22-5]: Upstream nix/ at the pinned tag
[^patchelf-674]: NixOS/patchelf#674
