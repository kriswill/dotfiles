---
type: Decision
title: 'Use Devenv''s Native Hook, Not Direnv, for cd Auto-Activation'
description: 'devenv projects auto-activate via devenv 2.1''s precmd hook instead of a direnvrc in ~/.config/direnv/lib, because devenv''s direnvrc redefines nix-direnv helpers with different bodies.'
tags: [devenv, direnv, zsh]
generated: { by: okflight/0.4.0, at: 2026-08-01T18:07:17-07:00 }
sources:
  - id: devenv-2-1-announcement-devenv-hook
    resource: https://devenv.sh/blog/2026/05/07/devenv-21-nix-with-zsh-fish-and-nushell-via-libghostty/
    title: devenv 2.1 announcement — `devenv hook`
---

**Status:** active. **Where:** [devenv](../modules/devenv.md),
[direnv](../modules/direnv.md).

## Context

Adding [devenv](../modules/devenv.md) with cd auto-activation. The repo's
existing idiom (see [direnv](../modules/direnv.md)) drops a tool's direnvrc
into `~/.config/direnv/lib`, where direnv sources every file in sorted order.
But devenv's direnvrc (emitted by `devenv direnvrc`, "adapted from
nix-direnv") redefines three nix-direnv helpers with different bodies —
`_nix_direnv_preflight`, `_nix_export_or_unset`, `_nix_import_env` — so
placing it beside `nix-direnv.sh` would let whichever file sorts last
silently corrupt the other's `use flake` / `use devenv`. Upstream's own
per-project answer (`eval "$(devenv direnvrc)"` in each `.envrc`) avoids
that, but devenv 2.1 shipped something better.

## Decision

Use devenv 2.1's native shell hook: a guarded `eval "$(devenv hook zsh)"` in
the stowed `integrations.zsh`, directly after the direnv hook. The hook is a
`precmd` function; entering a directory trusted via `devenv allow` spawns a
nested `devenv shell` (libghostty VT), and leaving `DEVENV_ROOT` exits it,
passing the destination back through `.devenv/exit-dir`. No `.envrc`, no
shared direnv lib dir, no nix-direnv interference — direnv continues to own
`use flake` projects untouched.

## Consequences

- The two per-directory-env systems coexist cleanly; trust is managed
  separately (`direnv allow` vs `devenv allow`/`devenv revoke`).
- Activation is prompt-driven: non-interactive shells (agents, scripts,
  CI) never auto-activate — use `devenv shell -- <cmd>` there.
- Inside a project the terminal is a *nested* shell, not the outer shell
  with extra vars; devenv watches project files and re-applies at the next
  prompt.
- Do not ever add devenv's direnvrc to `~/.config/direnv/lib` — the helper
  collision above is the failure mode this decision exists to avoid.

## Citations

- Helper collision verified against devenv 2.1.2's `devenv direnvrc` output
  vs nix-direnv's `direnvrc` (nixpkgs pin, 2026-08-01).
