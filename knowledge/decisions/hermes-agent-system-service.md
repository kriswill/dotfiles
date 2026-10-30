---
type: Decision
title: Run Hermes Agent as the Upstream NixOS System Service
description: 'nebula runs Hermes Agent through the upstream NixOS module (since vendored into flakes/hermes-agent) in native mode, with the service running as k rather than a hermes system user (hermes is single-owner, so two uids cannot share HERMES_HOME), a shared HERMES_HOME for CLI and gateway, and a sops-delivered Anthropic key; home-manager stays out, and the input is tag-pinned and un-followed because our nixpkgs'' patchelf breaks its prebuilt node.'
tags: [ai-agent, secrets, home-manager]
status: stable
generated: { by: claude-code/opus-5-5, at: 2026-10-30T03:00:00+00:00 }
sources:
  - id: hermes-nix-setup
    resource: https://hermes-agent.nousresearch.com/docs/getting-started/nix-setup
    title: 'Hermes Agent docs: Nix & NixOS Setup'
  - id: hermes-v0-22-5
    resource: https://github.com/NousResearch/hermes-agent/releases/tag/v0.22.5
    title: 'Hermes Agent v0.22.5 release'
---

**Where:** [hermes-agent](../modules/hermes-agent.md),
[nebula-hermes-agent](../modules/nebula-hermes-agent.md), the
[hermes-agent sub-flake](../packages/hermes-agent.md).

This record describes the first cut, which consumed upstream's flake
directly. The module and the package then moved into a trimmed copy of
upstream's `nix/`
([hermes-agent-vendored-nix](hermes-agent-vendored-nix.md)). The wrapper
and the `2750` mode below became module behaviour there, and the input
notes now apply to the sub-flake's inputs.

## Context

Upstream ships three Nix integrations: the package (`nix profile install`),
a Home Manager module, and a NixOS module with native and container
modes. It recommends the Home Manager module for a one-person
machine.[^hermes-nix-setup] This repo
[retired home-manager](home-manager-retirement.md) and does not bring it
back, not even as a transitive lock entry. The options that remained were the
NixOS system service, a CLI-only install (package on PATH, `~/.hermes`
configured with `hermes setup`), or container mode. Container mode would add
Docker or Podman, which nebula doesn't run today.

## Decision

Use the upstream NixOS module in **native mode, running as k**:

- `services.hermes-agent.enable` with `addToSystemPackages`, so k's
  interactive CLI shares the gateway's `/var/lib/hermes/.hermes`.
- `user = "k"`, `createUser = false`, `group = "hermes"` (a group with no
  members). This replaced the first cut (commit-less, 2026-10-29): module
  default `hermes` user, k in the `hermes` group. k's CLI failed with
  `Error: storage_unavailable`. That particular error turned out to come from
  a stray unmanaged `~/.hermes` (next bullets), but the shared-group design
  is broken on its own. A rootless two-uid bench (user+mount
  namespace with subuid maps, inner uid 983 for the gateway and 1000 in group
  983 for the CLI, the module's `2770` layout) showed why. Gateway boot alone
  leaves `HERMES_HOME` at `0700`: `secure_parent_dir()` chmods a credential's
  parent with no managed-mode check (still true on main), and seeding
  `ANTHROPIC_API_KEY` into the credential pool writes `auth.json` straight
  into the home. `state.db`, its WAL files, `auth.json`, `install_id` and the
  locks are `0600`. Hermes also enforces one owner: the gateway lock refuses
  a file another uid owns, the control socket wants an owner-only dir (181
  non-test files force `0600`, 8 compare `st_uid` with `getuid()`), and the
  gateway refuses sessions whose cwd it can't see. Patching that was
  rejected: it would rewrite a deliberate security model. The CLI-as-`hermes`
  alternative (a sudo wrapper) would keep the agent out of k's projects. On
  the same bench with one uid, the CLI ran a session through the gateway to
  the provider (HTTP 401 for the bench's dummy key).
- The CLI gets `HERMES_HOME` from a wrapper (`--set-default`), not from
  `addToSystemPackages`. That option only sets `environment.variables`, which
  is skipped by every shell under a running session: they inherit
  `__NIXOS_SET_ENVIRONMENT_DONE=1`, and so does herdr's long-lived server.
  `hermes` then silently created an unmanaged `~/.hermes` (first created by a
  build smoke-test that ran `hermes --version`). Its auto-started local
  gateway refused every session with `storage_unavailable at
  restore_policy: invalid policy`. That was the error k actually hit.
- An activation snippet drops group-write from `HERMES_HOME` after upstream's
  `chmod 2770`. With one owner the CLI otherwise refuses the gateway:
  `unsafe_control_permissions`, because group-write is allowed only through
  the owner's private group. Verified live: with `HERMES_HOME` unset, the
  wrapped CLI ran a prompt through the k-run gateway (exit 0).
- `settings.model` is `anthropic` / `claude-opus-5-5`; the key comes from a
  new `hermes-env` sops secret through `environmentFiles`.
- The flake input is pinned to the `v0.22.5` release tag, because upstream
  rates Nix "Tier 2": main may break the flake.[^hermes-v0-22-5]
- Like the [hyprland input](hyprland-unfollow-cachix.md), it does **not**
  follow our nixpkgs, but for correctness, not cache hits:
  `hermes-agent.cachix.org` had neither the tag's nor main's `default`
  package on 2026-10-29. The package autopatchelfs a prebuilt node 26.12.1
  from upstream's `pm/lock.json`. Against our nixpkgs (2026-10-23: glibc
  2.44, gcc 16.2, patchelf 0.19.2) the patched binary segfaults on
  `node --version`, because patchelf 0.19.2 corrupts executables whose ELF
  headers it has to move (NixOS/patchelf#674). The TUI build then dies at
  `npm config set offline true` (exit 139). The tag's own nixpkgs
  (2026-07-29) predates that patchelf and its node runs. Un-followed, our
  package drv equals upstream's own `v0.22.5` `default`
  (`f0n13448…-hermes-agent-0.0.0`). Upstream main carries a patched patchelf
  (post-v0.22.5); re-add the follow once a release tag ships it.
- `inputs.flake-parts.follows` stays (lib only, no drv effect), and
  `inputs.home-manager.follows = ""` cuts upstream's checks-only home-manager
  input.
- Lock gotcha: dropping an existing `follows` makes `nix flake lock`
  re-resolve that input to the latest `nixos-unstable` instead of copying the
  dependency's lock. `nix flake update hermes-agent` restores the tag's own
  pins.

## Consequences

- Config, the service and the secret are declarative. The gateway (messaging,
  cron, memory) runs whether k is logged in or not. k does not linger, so
  cron runs unscoped workers until the gateway restarts inside a session,
  instead of restart-safe `systemd-run --user` scopes.
- The gateway runs as k: `ProtectSystem=strict` limits its writes to
  `/var/lib/hermes`, but it reads with k's access. That's acceptable with no
  messaging platforms configured. Revisit before enabling one, because a
  chat message could then drive an agent with k's read access.
- Switching from the first cut needed a one-time `chown -R k:hermes
  /var/lib/hermes`: activation chowns only the top-level state dirs, and the
  old `hermes` user's `0600` files would otherwise lock k out.
- `hermes setup` and `hermes config set` are blocked. Every config change is
  a Nix edit plus a rebuild.
- Hermes brings its own nixpkgs (a second evaluation and its own
  glibc/python in the closure). Most of that is on cache.nixos.org because
  the rev is a channel rev. The hermes derivations themselves (uv2nix venv,
  web/TUI bundles) build locally. Updating is now a port of upstream's `nix/`
  changes into the sub-flake (see
  [hermes-agent-vendored-nix](hermes-agent-vendored-nix.md)).
- The first rebuild needs the `hermes-env` key in `secrets.yaml`: sops-nix
  fails the build on a declared key it can't find.

[^hermes-nix-setup]: Hermes Agent docs: Nix & NixOS Setup
[^hermes-v0-22-5]: Hermes Agent v0.22.5 release
