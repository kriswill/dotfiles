---
type: Decision
title: Keep Upstream Noctalia's NixOS Module Over Nixpkgs'
description: nixpkgs' new programs.noctalia module is disabled on nebula so the upstream noctalia-shell flake module keeps sole ownership of the programs.noctalia option namespace — the flake input IS upstream, pinned in lockstep with the installed binary.
tags: [nixos, noctalia, modules]
timestamp: '2026-08-02T15:00:13-07:00'
---

**Status:** active. **Where:** [users-k-noctalia](../modules/users-k-noctalia.md).

## Context

nixos-unstable grew its own `programs.noctalia` module
(`nixos/modules/programs/wayland/noctalia.nix`), carried into flake.lock by
the nixpkgs bump to `148bab9` in commit `25f9332`. snowglobe-lib's
`mkNixosHost` imports upstream noctalia-shell's `nixosModules.default` into
every host it builds, and that module declares the same
`programs.noctalia.enable` option — two declarations of one option is a
module-system eval error, so [nebula](../hosts/nebula.md) stopped
evaluating. The breakage sat unnoticed until the next flake.lock bump's
pre-push cross-eval gate (`nix eval
.#nixosConfigurations.nebula.config.system.build.toplevel.drvPath`).

## Decision

Keep the flake module and drop nixpkgs' copy from the eval:
`disabledModules = [ "programs/wayland/noctalia.nix" ]` in the noctalia host
file. The `noctalia` flake input is upstream noctalia itself, pinned and
bumped by us, so its module always matches the installed binary; nixpkgs'
module would instead wire up nixpkgs' own noctalia build at whatever version
the channel happens to carry.

## Consequences

- nebula evaluates again; the shell keeps coming solely from the pinned
  input, and module semantics track upstream instead of the channel.
- The `disabledModules` line must survive as long as both modules declare
  `programs.noctalia`. If snowglobe-lib ever stops importing the flake
  module (or nixpkgs renames its namespace), the line — and the collision —
  go away together.

## Citations

- Commits `25f9332` (nixpkgs bump that introduced the collision), `bd81c2a`
  (flake.lock bump whose eval gate surfaced it)
- [nixpkgs `nixos/modules/programs/wayland/noctalia.nix`](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/programs/wayland/noctalia.nix)
