---
type: Runtime
title: Nix Runtime
description: 'The executable half of Nix — evaluator, immutable /nix/store, and privileged nix-daemon realising derivations; every host here runs Determinate Nix, chosen for the ≥2.26 relative-path locking the sub-flakes depend on.'
tags: [nix, runtime, determinate]
timestamp: '2026-08-02T17:10:00-07:00'
---

Nix is two things wearing one name. The [language](../languages/nix.md) is
the pure, lazy DSL; this is the machinery that executes it: an evaluator
that reduces expressions to derivations, an immutable content-addressed
`/nix/store`, and a privileged `nix-daemon` that client commands talk to
over a socket to realise those derivations — sandboxed builds, binary-cache
substitution, garbage collection. Every `nix`, `darwin-rebuild`,
`nixos-rebuild`, and direnv invocation in this repo is a client of that
daemon.

## How this repo uses it

- **Implementation: Determinate Nix on every host.** On the Macs it is
  installer-managed and nix-darwin keeps its hands off
  (`nix.enable = mkForce false` in [core](../modules/core.md)); on nebula
  the [determinate](../modules/determinate.md) module's plain `nix.package`
  assignment outbids snowglobe-lib's Lix `setDefault`. Either way
  `determinate-nixd` owns `/etc/nix/nix.conf`, including the class-generated
  settings via `nix.custom.conf`.
- **Why this runtime:** the `./flakes/*` relative-path sub-flake inputs need
  Nix ≥ 2.26's parent-relative locking, which Lix froze out — the switch is
  recorded in [Replace Lix With Determinate Nix](../decisions/lix-to-determinate.md).
  Lazy trees (default in Determinate ≥ 3.5) also stop every eval copying
  the whole repo into the store.
- **Registry and caches:** the flake registry's `nixpkgs` is pinned to this
  flake's own input (overriding Determinate's nixpkgs-weekly default), and
  the FlakeHub cache + install.determinate.systems substituters are
  declared declaratively.
- **One daemon per machine is a contract.** Tools that shell out to `nix`
  must use the host's runtime rather than bundle their own — a
  shell-provided nix would disagree with the daemon about store paths and
  registry pins. Dev environments honour it by omission: nix is deliberately
  absent from project devShells and [devenv](../modules/devenv.md)
  environments (the flake-explorer convention — see
  [the devenv lock decision](../decisions/devenv-lock-derived-from-flake-lock.md)),
  and [direnv](../modules/direnv.md)'s cached shells are snapshots of what
  this daemon last built.

## Citations

- [Nix Reference Manual — the Nix store](https://nix.dev/manual/nix/stable/store/)
- [Determinate Systems documentation](https://docs.determinate.systems/)
