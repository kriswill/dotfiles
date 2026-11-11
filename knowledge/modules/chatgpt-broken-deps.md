---
type: NixOS Module
title: ChatGPT Broken Deps
description: 'Temporary nebula workaround for two ChatGPT app dependencies that don''t build at the flake''s nixpkgs pin: gives tectonic the aws-lc input nixpkgs left out and runs the app on its bundled codex, until nixpkgs'' tectonic and codex build again; then it switches itself off and warns.'
resource: modules/hosts/nebula/chatgpt-broken-deps.nix
tags: [nixos-module, host-specific, temporary]
generated: { by: claude-code/fable-5.2, at: 2026-11-10T19:45:00-08:00 }
sources:
  - id: nixpkgs-tectonic-fix
    resource: https://github.com/NixOS/nixpkgs/commit/743696b7
    title: 'nixpkgs 743696b7: tectonic-unwrapped: fix build with system libs'
  - id: nixpkgs-codex-fix
    resource: https://github.com/NixOS/nixpkgs/commit/16b46369
    title: 'nixpkgs 16b46369: codex: fix build with sys libs'
---

An overlay on [nebula](../hosts/nebula.md) for the two packages the
[ChatGPT app](chatgpt.md) swaps in for its bundled binaries. nixpkgs' rust
hooks now tell vendored `-sys` crates to link system libraries
(`AWS_LC_SYS_USE_SYSTEM`), and each package has to list them as inputs. At
the 2026-11-07 pin tectonic and codex didn't, so `aws-lc-sys`' build script
panics. Both were fixed upstream within days.[^nixpkgs-tectonic-fix][^nixpkgs-codex-fix]

- **tectonic** gets `aws-lc` in `buildInputs`, as upstream added it.
- **codex** is left out: `chatgpt.override { codex = null; }` runs the app
  on the codex OpenAI bundles (a static binary, 0.166.0-alpha.6 on
  2026-11-10) instead of nixpkgs'. Adding codex's inputs the same way builds
  on nebula (19 min on 24 cores), but nothing caches the result, and
  compiling it took down the 4-core, 15 GiB CI runner after two hours.

Each half checks whether nixpkgs' package already lists `aws-lc` and leaves
it alone if so. Once both do, a NixOS warning names the file to delete, on
`nrs` and in the weekly flake.lock PR's CI. Deleting it puts the app back on
nixpkgs' codex.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/chatgpt-broken-deps.nix`](../../modules/hosts/nebula/chatgpt-broken-deps.nix)

[^nixpkgs-tectonic-fix]: nixpkgs 743696b7: tectonic-unwrapped: fix build with system libs
[^nixpkgs-codex-fix]: nixpkgs 16b46369: codex: fix build with sys libs
