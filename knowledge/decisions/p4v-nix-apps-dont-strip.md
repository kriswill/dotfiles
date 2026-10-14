---
type: Decision
title: Install P4V From nixpkgs With Stripping Disabled
description: 'Host k gets P4V/P4Admin/P4Merge from the nixpkgs p4v package, bumped to 2026.3 and built with dontStrip so Perforce''s notarized signature survives, through systemPackages so the bundles land in /Applications/Nix Apps where Spotlight indexes them.'
tags: [darwin, perforce, apps, codesign]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-14T19:22:08+00:00 }
sources:
  - id: nixpkgs-p4v-package
    resource: https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/pkgs/by-name/p4/p4v/package.nix
    title: nixpkgs p4v package (2026.1, web.archive.org-pinned sources, unfreeRedistributable)
  - id: nixpkgs-p4v-darwin
    resource: https://github.com/NixOS/nixpkgs/blob/6510408d147d8c5e6d76043e899e9251756f6a75/pkgs/by-name/p4/p4v/darwin.nix
    title: nixpkgs p4v darwin builder (undmg, bundles moved into $out/Applications)
  - id: nix-darwin-applications
    resource: https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/applications.nix
    title: nix-darwin applications module (systemPackages → /Applications/Nix Apps)
---

**Where:** [k](../hosts/k.md), [core](../modules/core.md).

## Context

P4V had been installed by dragging the Perforce DMG's bundles into
`/Applications`. nixpkgs packages it for aarch64-darwin, but at 2026.1, with
sources pinned to web.archive.org snapshots because Perforce reissues patch
builds under the same URL.[^nixpkgs-p4v-package] Its darwin builder unpacks the
DMG and moves the bundles into `$out/Applications` untouched,[^nixpkgs-p4v-darwin]
but stdenv's fixup phase then runs `strip -S` over `Applications/` as well as
`bin/`. That rewrote 54 Qt framework binaries in `p4v.app` alone, and
`codesign --verify --deep --strict` rejected all three bundles ("code has no
resources but signature indicates they must be present"). The same bundles
verify inside the DMG.

## Decision

- `modules/hosts/k/default.nix` overrides `pkgs.p4v` with `version = "2026.3"`,
  `dontStrip = true`, and a `fetchurl` of Perforce's r26.3 DMG. With stripping
  off, the store bundles are byte-identical to the DMG's, and `spctl` accepts
  them as Notarized Developer ID (Perforce Software, Inc., `PYYFSY54S7`).
- The package goes in `environment.systemPackages`, not
  `users.users.k.packages`: nix-darwin copies only systemPackages'
  `Applications/` into `/Applications/Nix Apps` as real directories, which
  Spotlight indexes.[^nix-darwin-applications]
- `p4v` (license `unfreeRedistributable`) is the first entry in the
  `allowUnfreePredicate` list in `modules/darwin/core.nix`, per
  [unfree-default-deny](unfree-default-deny.md).

## Consequences

- P4V, P4Admin and P4Merge show up in Spotlight and update with rebuilds,
  replacing the drag-installed copies.
- `src` points at Perforce's live URL, not an archive snapshot. When Perforce
  reissues 26.3, the fixed-output hash mismatches and the rebuild fails. That
  failure is the signal to update the hash or bump the release.
- Plain `pkgs.p4v` has the same strip problem. Drop `dontStrip` only once
  nixpkgs sets it upstream.

Landed in commit `e82d017`.

[^nixpkgs-p4v-package]: nixpkgs p4v package (2026.1, web.archive.org-pinned sources, unfreeRedistributable)
[^nixpkgs-p4v-darwin]: nixpkgs p4v darwin builder (undmg, bundles moved into $out/Applications)
[^nix-darwin-applications]: nix-darwin applications module (systemPackages → /Applications/Nix Apps)
