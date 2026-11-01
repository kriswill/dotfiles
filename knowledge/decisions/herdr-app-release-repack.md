---
type: Decision
title: Repackage Herdr's Release Builds Instead of Building or Caching Source
description: 'The herdr sub-flake wraps upstream''s prebuilt herdr-core and Herdr tarballs rather than building from source or consuming a cached source build (nixpkgs#581031, numtide''s llm-agents.nix), because a repack has no build cost to cache, follows near-daily releases within the hour, and keeps hc''s static binary that `hc machine add` can copy.'
tags: [herdr, packaging, binary-cache]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-11-01T12:00:00-08:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/herdr/README.md
    title: 'flakes/herdr/README.md (why repackaged release builds)'
  - id: nixpkgs-pr-581031
    resource: https://github.com/NixOS/nixpkgs/pull/581031
    title: 'NixOS/nixpkgs#581031 herdr-core, herdr-desktop: init'
  - id: llm-agents
    resource: https://github.com/numtide/llm-agents.nix
    title: 'numtide/llm-agents.nix (herdr-core, herdr-app; cache.numtide.com)'
  - id: core-manifest
    resource: https://releases.herdr.dev/app/latest.json
    title: 'releases.herdr.dev manifests (what upstream''s installers read)'
---

**Where:** [herdr sub-flake](../packages/herdr.md).

## Context

Herdr's desktop app and herdr-core arrived on 2026-10-16 as pre-1.0 projects
releasing about once a day: core 0.1.16 and app 0.1.11 on 2026-10-31. They
publish no GitHub releases, only tags plus per-target tarballs and sha256s in
`releases.herdr.dev/{core,app}/latest.json`.[^core-manifest] The goal was a
cached package, so nothing compiles on nebula. A source build needs Rust,
Zig 0.16 and a vendored Ghostty with fetched Zig deps.

The options on 2026-11-01:

- **nixpkgs.** #581031 builds both from source. It was open and awaiting a
  reviewer. Once merged it's Hydra-cached, but behind upstream by days to
  weeks.[^nixpkgs-pr-581031]
- **numtide's llm-agents.nix.** Current source builds, updated daily, on
  `cache.numtide.com`. The cache only hits with their nixpkgs, which means a
  second nixpkgs evaluation and library closure.[^llm-agents]
- **herdrdev/herdr-nix.** Upstream's cachix covers only the herdr TUI.

## Decision

Repackage the release tarballs: fetchurl with the manifest's hash, converted
to SRI by `update.ts`, then patchelf for the app. The core is static-pie and
needs nothing. The "build" downloads the same bytes a substituter would send
and finishes in seconds; nebula's whole dry build took 15 s. So there's no
build cost for a cache to save, and no cache to configure.

`programs.herdr-app.package` and `programs.herdr-core.package` still accept a
source build, so switching to nixpkgs or numtide is one line.

## Consequences

- Updates follow upstream as fast as `update.ts` runs, and
  herdr-update-check flags them.
- `hc` is upstream's static binary, so `hc machine add` can copy it to
  another machine. A Nix-linked source build can't, so #581031 downloads
  upstream's build for it.[^nixpkgs-pr-581031]
- The bits are the ones upstream signs and ships, and they are release
  builds. That means release-only behaviour stays on and needs handling:
  telemetry is on by default (the module turns it off), and the self-updater
  is kept off by where the icon goes. A source build has neither.
- `sourceProvenance` is `binaryNativeCode`. Patching the binary is limited to
  its ELF headers. Source-level fixes, such as nixpkgs' `xdg-open` path
  substitution, aren't possible here, so `xdg-open` comes from the system
  PATH.[^subflake-readme]

Not yet committed (2026-11-01).

[^subflake-readme]: `flakes/herdr/README.md`: why repackaged release builds; packaging notes
[^nixpkgs-pr-581031]: NixOS/nixpkgs#581031: the PR and its notes for review
[^llm-agents]: numtide/llm-agents.nix README: Binary Cache ("only hits when your nixpkgs revision matches ours")
[^core-manifest]: releases.herdr.dev `latest.json` manifests
