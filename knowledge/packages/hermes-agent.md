---
type: Sub-flake
title: hermes-agent
description: 'Sub-flake that builds Nous Research''s Hermes Agent (the hermes CLI and its messaging/cron gateway) from a trimmed, path-rewritten copy of upstream''s nix/ against the v0.23.0 source for Linux and aarch64-darwin, plus single-owner services.hermes-agent modules for NixOS (wrapped CLI, 2750 state, Herdr integration option) and nix-darwin (launchd agent inside a Seatbelt sandbox); enabled on nebula and mini.'
resource: flakes/hermes-agent/
tags: [sub-flake, package, ai-agent]
generated: { by: hermes-agent/gpt-6-astra, at: 2026-11-01T18:02:53-08:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/hermes-agent/README.md
    title: 'flakes/hermes-agent/README.md (layout, outputs, module changes, bumping the tag)'
  - id: upstream-nix-v0-23-0
    resource: https://github.com/NousResearch/hermes-agent/tree/v0.23.0/nix
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
  `v0.23.0`. `nix/packages.nix` turns it into `hermesSrc`, a path value at its
  root, and a `lib.makeScope` hands it to every `callPackage`. Upstream's
  `../x` becomes `hermesSrc + "/x"`. It has to be a path: `lib.fileset`
  rejects strings, and copying a path is what reproduces upstream's filtered
  store paths. The original import was drv-identical to upstream with
  `version = "0.0.0"`; runtime repairs for dependency receipts and writable
  skill copies now intentionally diverge. Review those local patches on bumps.
- **Outputs.** `packages.<system>.hermes-agent` (and `default`) is upstream's
  `full` package with `version` set to the tag. Upstream leaves it at
  `0.0.0`, so `hermes --version` printed `v0.0.0`. `nixosModules.default` and
  `darwinModules.default` are the modules; the darwin one confines Hermes
  with Seatbelt
  ([decision](../decisions/hermes-agent-macos-seatbelt-sandbox.md)). The root re-exports the package in `modules/packages.nix` and
  the module as [hermes-agent](../modules/hermes-agent.md).
- **Dropped:** the desktop app (Electron), the dev shell, home-manager, the
  checks suite, the overlay, the sandbox, the per-tool `pm-*` packages, and
  `update-npm-lockfile`, which was the only user of the `npm-lockfile-fix`
  input. Container mode is gone from the module.
- **No nixpkgs follow.** The other inputs (nixpkgs, pyproject-nix, uv2nix,
  pyproject-build-systems) are locked to the revs in the tag's own
  `flake.lock`. Up to v0.22.5 a follow was impossible: the package
  autopatchelfs a prebuilt node, and patchelf 0.19.2 corrupted
  it.[^patchelf-674] Since v0.23.0 `nix/pm-packages.nix` patches patchelf
  itself, so a follow could return, but it is untried. The root's input
  follows only flake-parts.
- **PM dependency receipts.** The package ships PM-pinned ffmpeg/ripgrep and
  registers them with node/npm in an immutable tool store, bound through the
  install stamp's `runtimeDir`. Receipts contain pinned archive identities and
  realized-tree digests after Nix fixups, not fabricated attestations for
  differently built nixpkgs tools. A fresh-home `hermes pm doctor` passes;
  corrupt digests/archive identities or missing trees still fail. The package's
  ffmpeg is 9.0.1; [nebula](../modules/nebula-hermes-agent.md)'s terminal profile
  independently supplies nixpkgs ffmpeg.
- **Writable skills.** The local `writable-skill-copies.patch` fixes initial
  seed, replacement, explicit restore and optional restore from Nix-store
  sources. Copied directories gain owner read/write/search and regular files
  gain owner read/write, retaining executable bits. Symlinks are not followed
  for copying or permission repair. Existing user edits remain protected by
  upstream's hash-based ownership checks. Older profile copies need a one-time
  owner-permission repair; do not chmod the store or symlink targets.
- **Herdr migration.** With the declarative shell hooks present, config merge
  drops only `herdr-agent-state` from `plugins.enabled`, leaving other entries
  and settings untouched.
- **TUI terminal breadcrumbs.** A local TypeScript patch follows committed
  session state (including compaction) and maintains the same tty-keyed
  continuation files as the classic CLI. Without it, Herdr's gateway hooks
  could not find a TUI session's live pane and left the spinner idle. The
  [integration decision](../decisions/hermes-herdr-integration-shell-hook.md)
  records routing and remote-launch restrictions; regression tests run during
  the Nix TUI build.
- **Bumping** means reading upstream's `nix/` diff between tags, porting it
  into the copies, re-locking those inputs to the new tag's lock, and
  re-checking parity.[^upstream-nix-v0-23-0]

Enabled on [nebula](../hosts/nebula.md) by
[nebula-hermes-agent](../modules/nebula-hermes-agent.md) and on
[mini](../hosts/mini.md) by
[mini-hermes-agent](../modules/mini-hermes-agent.md). Consumed by the
root flake as a relative-path input. See the
[sub-flake extraction pattern](../patterns/subflake-extraction.md).

## Source

- Flake: [`flakes/hermes-agent/`](../../flakes/hermes-agent/)
- README: [`flakes/hermes-agent/README.md`](../../flakes/hermes-agent/README.md)

[^subflake-readme]: flakes/hermes-agent/README.md
[^upstream-nix-v0-23-0]: Upstream nix/ at the pinned tag
[^patchelf-674]: NixOS/patchelf#674
