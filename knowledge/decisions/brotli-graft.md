---
type: Decision
title: Graft Brotli 1.2.1 Instead of Rebuilding Its Dependents
description: 'nebula swaps brotli 1.2.1 (CVE-2026-111497, a decoder out-of-bounds write reachable from curl, libsoup, Qt, Node and others) into its built system with system.replaceDependencies, because brotli sits under 633 of ~3000 store paths that an override would recompile; a patched rewriter (nixpkgs PR #579409, plus a filesystem rewrite so renamed entries cannot unsort a NAR) catches compiler-garbled store paths, and it all switches off with a warning once nixpkgs ships 1.2.1.'
tags: [nixploit, cve, brotli, replace-dependencies]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-26T19:10:00-07:00 }
sources:
  - id: ghsa-111497
    resource: https://github.com/advisories/GHSA-9v8h-qqgm-4m35
    title: 'GHSA-9v8h-qqgm-4m35 / CVE-2026-111497: Brotli decoder out-of-bounds write ("Node2Shell")'
  - id: brotli-121
    resource: https://github.com/google/brotli/releases/tag/v1.2.1
    title: 'brotli v1.2.1 release (2026-10-21)'
  - id: nixpkgs-577208
    resource: https://github.com/NixOS/nixpkgs/pull/577208
    title: 'nixpkgs #577208: brotli 1.2.0 -> 1.2.1 (merged into staging 2026-10-22)'
  - id: replace-dependencies
    resource: https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/replace-dependencies.nix
    title: 'nixpkgs replaceDependencies (same-length names, cutoffPackages, import-from-derivation)'
  - id: nixpkgs-579409
    resource: https://github.com/NixOS/nixpkgs/pull/579409
    title: 'nixpkgs #579409: replaceDirectDependencies: try rewriting with more effort (open)'
---

**Where:** [brotli-graft](../modules/brotli-graft.md) on
[nebula](../hosts/nebula.md); found by
[nebula-nixploit](../modules/nebula-nixploit.md).

## Context

nixploit flagged brotli 1.2.0 for CVE-2026-111497 (9.2): a crafted stream
makes the decoder write out of bounds, which can lead to code
execution.[^ghsa-111497] 1.2.1 fixes it (2026-10-21).[^brotli-121] On nebula
the library sits under curl/libcurl (and git over HTTPS), libsoup, Qt
networking, Node, aiohttp, Wireshark and freetype. Several of those decode
brotli straight off the network.

nixpkgs merged 1.2.1 into `staging` on 2026-10-22, and into the 26.05
staging branches.[^nixpkgs-577208] `staging-next`, `master` and
`nixos-unstable` were still on 1.2.0 on 2026-10-26, a one-to-three-week wait.
An override is out: 633 of the system's 3008 store paths (12.6 of 28.1 GiB)
depend on brotli, including Chromium, two Electrons and GIMP, and every one
would recompile.

## Decision

Use `system.replaceDependencies`. It builds only the replacements, then
copies every dependent path and rewrites its references.[^replace-dependencies]
Five pairs: `brotli.{lib,out,dev}`, the 32-bit `pkgsi686Linux.brotli.lib`, and
the Python module rebuilt against 1.2.1 to drop the 1.2.0 name. The names keep
their length, which the rewrite requires. Determinate Nix already bundles its
own 1.2.1.

The stock rewriter left 153 paths on 1.2.0, all through GIMP. gimptool holds
GIMP's store path with the name half garbled by the compiler
(`…-gimp...;|...`), so the `hash-name` rewrite missed it. Nix still sees the
intact hash as a reference, so the old GIMP stayed with its old graphviz,
freetype, curl and libsoup. nixpkgs PR #579409, opened the same day for the
same brotli path, also rewrites the bare hash when old and new names
match.[^nixpkgs-579409]

With that patch, Battle.net's Proton FHS root then failed to build: "NAR
directory is not sorted". The rewriter edits a NAR stream with `sed` and
never re-sorts it, and the root holds two sibling gdb auto-load dirs named
after store paths (`usr/share/gdb/auto-load/nix/store/<hash>-gstreamer-1.28.7`,
64- and 32-bit). Rewritten, `2s02…` and `vcz8…` became `x0qm…` and `i7d3…`,
which sort the other way. The first, stock build passed only because its new
hashes kept their order. `system-path` and the Steam, WoWUp and ProtonUp roots
have the same kind of dirs, so any nixpkgs update could break `nrs` and CI by
chance. Our copy of the rewriter therefore also copies directories and
rewrites contents, symlink targets and entry names on the filesystem. Nix
sorts entries itself when it registers the output. Single files and symlinks
keep the stream path. A fixture reproduced the failure with the stock
rewriter and built correctly with ours.

The first switch (generation 192) then showed a scanner side effect.
nixploit takes each store path's `pname`, `version`, `patches` and `src` from
its deriver, and a rewritten path's deriver is the rewrite step, a
`runCommandLocal` with only a name. 479 packages went unversioned, and every
advisory for them moved to "unknown", 22,724 in all, 7,366 for Chromium
alone. A new advisory against a rewritten package would have been buried
there. So each rewrite step now also declares what its name implies under
nixpkgs' naming:
- **Suffixes stripped:** output suffixes (`-dev`, `-lib`, `-bin`, …) and the
  `-env`/`-wrapped` wrappers, whose originals declare the plain version.
- **Prefixes stripped:** interpreter prefixes (`python3.14-`, `perl5.42.3-`,
  `ruby3.4-`). Python packages also get `dontWrapPythonPrograms`, the marker
  nixploit reads as PyPI.
- **webkitgtk:** its `+abi=…` suffix is dropped.
- **Left undeclared:** FHS, firmware and plugin wrappers (`-bwrap`,
  `-rootfs`, `-init`, `-profile`, `-extracted`, `-zstd`, `-only-plugins`),
  and config or system paths (`dbus-1`, `graphics-drivers`, `etc-*`,
  `nixos-system-*`, `security-wrapper-*`).

Each rule came from diffing `nixploit inventory` of the swapped system against
the same configuration with the swap forced off. At the end, both had 66
unversioned packages. The remaining identity differences were `zfs` named
`zfs-user` and `nixd nightly` dropped, plus the harmless `battlenet 0.1.0`
declared and `graphics-drivers 32bit` unversioned. A name can't carry the
rest:
- **Patch lists and source URLs:** advisories that nixpkgs patches, or that
  nixploit's upstream-history check would clear, can show as "affected" for
  rewritten packages.
- **Ecosystem markers:** 22 rewritten apps lose their crates.io, Go, npm or
  PyPI-application marker (both Electrons, atuin-desktop, lact, librsvg,
  Gajim, opensnitch-ui, zenmap, …). They still match NVD, just not OSV's
  per-ecosystem advisories.

Both gaps last until the swap retires. Copying the originals' attributes from
their `.drv` files would close them, but means parsing hundreds of
derivations, some with escaped-JSON attributes, during evaluation.

The copy lives in `_replace-direct-dependencies.nix` (the PR's version plus
our changes), swapped into `pkgs` with an overlay.
That overlay's check picks the attribute's value, never its name:
`nixpkgs.overlays` can't depend on `pkgs`, and an overlay's names can't
depend on `prev`.

Both pieces turn off when nixpkgs' own brotli reaches 1.2.1: the replacement
list goes empty, which also skips the import-from-derivation, and a NixOS
warning names the files to delete.

Rejected:

- **Overriding brotli.** That recompiles all 633 paths.
- **Waiting for nixpkgs.** It would leave a network-reachable decoder open
  for one to three weeks.

## Consequences

The swap compiles only brotli (twice) and the Python module. The rest is
copying: about 12.6 GiB more store. Each evaluation builds the base system
first (import-from-derivation), so `nrs` evaluates more slowly.

CI builds nebula's system on a GitHub runner that already frees disk to fit
it, and now also holds the rewritten copies. If that job runs out of space,
the options are a bigger runner or leaving the swap to nebula alone.

Switched on 2026-10-26 (generation 192). Landed in commit `9517d2b`.

[^ghsa-111497]: GHSA-9v8h-qqgm-4m35 / CVE-2026-111497: Brotli decoder out-of-bounds write ("Node2Shell")
[^brotli-121]: brotli v1.2.1 release (2026-10-21)
[^nixpkgs-577208]: nixpkgs #577208: brotli 1.2.0 -> 1.2.1 (merged into staging 2026-10-22)
[^replace-dependencies]: nixpkgs replaceDependencies (same-length names, cutoffPackages, import-from-derivation)
[^nixpkgs-579409]: nixpkgs #579409: replaceDirectDependencies: try rewriting with more effort (open)
