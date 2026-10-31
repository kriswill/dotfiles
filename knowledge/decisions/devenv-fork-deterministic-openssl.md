---
type: Decision
title: Pin openssl Dirs in the devenv Fork so Darwin Builds Are Host-Independent
description: 'The kriswill/devenv `custom` branch sets OPENSSL_LIB_DIR/OPENSSL_INCLUDE_DIR unconditionally in its crate2nix overrides and applies the openssl override to devenv-proxy — because openssl-sys probes Homebrew before pkg-config on darwin, so the same derivation linked on a clean Mac and failed with `ld: library not found for -lssl` on GitHub macOS runners.'
tags: [devenv, patch, ci, darwin]
generated: { by: claude-code/opus-5.5, at: 2026-10-31T00:00:00+00:00 }
sources:
  - id: devenv-fork
    resource: https://github.com/kriswill/devenv
    title: kriswill/devenv staging fork (custom branch)
  - id: openssl-sys-find-normal
    resource: https://github.com/sfackler/rust-openssl/blob/openssl-sys-v0.9.117/openssl-sys/build/find_normal.rs
    title: openssl-sys build script — host probing order
---

**Status:** accepted (2026-09-16), fork commit `ff4f079` (aws-lc follow-up
`b2b4a31`, 2026-10-31); dotfiles consumes
it via the `devenv` input bump. Candidate to upstream — `nix/crate-config.nix`
was byte-identical to upstream main before the change.
**Where:** fork `nix/crate-config.nix` (`opensslOverride`, new
`devenv-proxy` entry); [`flake.nix`](../../flake.nix) devenv input;
[`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) darwin-k job.

## Context

After the fork rebased onto devenv v2.3.1 (lock bump 2026-09-11), every
weekly lock update that moved nixpkgs failed the darwin-k CI job while
linking the new `devenv-proxy` crate (pingora's openssl backend):
`ld: library not found for -lssl`. The same lock built fine on host `k`.

Root cause, from the job logs: on `aarch64-apple-darwin` the openssl-sys
build script checks `/opt/homebrew/opt/openssl@3` *before* trying
pkg-config. Darwin nix builds are unsandboxed, GitHub's macos-26 image ships
Homebrew's openssl@3, so the script emitted
`cargo:rustc-link-search=/opt/homebrew/opt/openssl@3/lib`. The nix
cc-wrapper drops that `-L` as impure (`NIX_ENFORCE_PURITY`), leaving
`-lssl` unresolvable. The main `devenv` crate survived because its
`devenvBase` override put nix openssl in `buildInputs` and therefore a
store `-L` on its link line; `devenv-proxy` had no override at all. The
fork already pinned the dirs for *static darwin* with a comment naming this
exact probe, but left the regular build exposed. Runs between bumps passed
only because they fetched an already-built proxy from the FlakeHub cache.

## Decision

In `opensslOverride`, set `OPENSSL_LIB_DIR` / `OPENSSL_INCLUDE_DIR` to the
store paths on every platform (the build script takes them verbatim and
skips all host probing), keep `OPENSSL_STATIC` gated to static darwin as
before, and apply `opensslOverride` to `devenv-proxy` so the store lib dir
is on its own link line regardless of what openssl-sys emits. Verified by
building `packages.aarch64-darwin.devenv.devenvProxy` from the fork: the
openssl-sys log shows `OPENSSL_LIB_DIR = /nix/store/…-openssl-3.6.3/lib`
and no Homebrew path, and the proxy link line carries the store `-L`.

## Consequences

- The proxy derivation now depends only on store inputs — identical on a
  clean Mac, a Homebrew Mac, and CI. Lock bumps no longer re-expose the
  failure.
- One more fork commit to carry across upstream tag rebases (drop it once a
  PR lands upstream).
- CI red on `main` had three distinct causes that week; this fixes the
  deterministic one. The podman 6.1.1 darwin zip hash in
  [`pkgs/podman.nix`](../../pkgs/podman.nix) was corrected in the same
  change; the aws-lc-sys `posix_spawn` failure was runner resource
  exhaustion and is not addressed here.

## Follow-up: keep aws-lc vendored (2026-10-31)

The nixpkgs bump to `1c89083` broke the link of the main `devenv` crate on
nebula with `rust-lld: undefined symbol: ERR_get_error_all`. nixpkgs had
changed `defaultCrateOverrides.aws-lc-sys` for aws-lc-sys >= 0.42 (devenv
locks 0.42.0) from the cmake builder, which vendors aws-lc, to
`AWS_LC_SYS_USE_SYSTEM = 1` against the shared `aws-lc` package. That
package's `lib/` ships its own `libcrypto.so`/`libssl.so`, and its `-L`
came before openssl's on the link line, so openssl-sys's `-lcrypto` bound to
aws-lc, which lacks the OpenSSL 3 symbol. The same `-L`-ordering hazard this
record already pins against, from a different direction.

Fork commit `b2b4a31` adds an `aws-lc-sys` entry to `nix/crate-config.nix`
that restores the cmake builder (`AWS_LC_SYS_CMAKE_BUILDER = 1`). The fork's
entries replace nixpkgs' (`defaultCrateOverrides // crateConfig`), so the
system-lib override never applies. Verified on nebula: devenv's
`libcrypto.so.3` resolves to `openssl-3.5.9`, and the nebula toplevel
builds. Darwin is evaluated only, not built. Drop the entry if upstream
devenv or nixpkgs stops `aws-lc`'s `lib/` from shadowing openssl.
