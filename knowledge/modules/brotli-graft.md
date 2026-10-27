---
type: NixOS Module
title: Brotli Graft
description: 'Swaps brotli 1.2.1 (the CVE-2026-111497 fix) into nebula''s built system with system.replaceDependencies, rewriting the ~630 store paths that depend on 1.2.0 instead of recompiling them, until nixpkgs ships 1.2.1; then it switches itself off and warns.'
resource: modules/hosts/nebula/brotli-graft.nix
tags: [nixos-module, host-specific, cve]
generated: { by: claude-code/opus-5.5, at: 2026-10-26T18:50:00-07:00 }
sources:
  - id: ghsa-111497
    resource: https://github.com/advisories/GHSA-9v8h-qqgm-4m35
    title: 'GHSA-9v8h-qqgm-4m35 / CVE-2026-111497: Brotli decoder out-of-bounds write ("Node2Shell")'
  - id: replace-dependencies
    resource: https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/replace-dependencies.nix
    title: 'nixpkgs replaceDependencies (same-length names, cutoffPackages, import-from-derivation)'
---

Swaps brotli 1.2.1 into [nebula](../hosts/nebula.md)'s system in place of
1.2.0, which has an out-of-bounds write in its decoder.[^ghsa-111497] Why a
swap rather than an override, and what it costs, is in the
[decision](../decisions/brotli-graft.md).

`system.replaceDependencies.replacements` gets five pairs: `brotli.{lib,out,dev}`,
the 32-bit `pkgsi686Linux.brotli.lib` (Steam's FHS roots), and the Python
module rebuilt against 1.2.1. The Python module links the system library, so
it's rebuilt only to drop the 1.2.0 name from the closure and from
[nixploit](nebula-nixploit.md)'s report. The names keep their length (1.2.0
→ 1.2.1), which the rewrite requires.[^replace-dependencies] The initrd is
exempt by default (`cutoffPackages`).

An overlay swaps in a patched rewriter, `_replace-direct-dependencies.nix`. It
adds nixpkgs PR #579409's bare-hash rewrite, which catches store paths whose
name half the compiler garbled (gimptool). It also rewrites directories on the
filesystem rather than as a NAR stream, because renaming sibling entries named
after store paths could unsort the NAR and fail the build. Details are in the
decision.

Retirement is automatic. `needed` compares nixpkgs' own `brotli.version` with
1.2.1. Once nixpkgs ships it, the list is empty, which also skips the
import-from-derivation, and a NixOS warning names the file to delete. The weekly
flake.lock PR's CI build and `nrs` both show it.
[gajim-pillow](gajim-pillow.md) retires the same way.

Determinate Nix bundles its own brotli 1.2.1, so the nix CLI and daemon
needed no swap.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/brotli-graft.nix`](../../modules/hosts/nebula/brotli-graft.nix)

[^ghsa-111497]: GHSA-9v8h-qqgm-4m35 / CVE-2026-111497: Brotli decoder out-of-bounds write ("Node2Shell")
[^replace-dependencies]: nixpkgs replaceDependencies (same-length names, cutoffPackages, import-from-derivation)
