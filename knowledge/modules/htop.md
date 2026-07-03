---
type: Darwin Module
title: Htop
description: 'Kris'' htop (system-level port of the old home-manager programs.htop).'
resource: modules/darwin/htop.nix
tags: [darwin-module]
timestamp: '2026-06-28T18:27:01-07:00'
---

Kris' htop (system-level port of the old home-manager programs.htop). home-manager rendered programs.htop.settings into an immutable (read-only) ~/.config/htop/htoprc symlinked from the store. nix-darwin has no programs.htop, so we reproduce that exactly: generate the same htoprc with writeText and link it during activation. Keeping it a store symlink (rather than a stow file) preserves the immutability — htop rewrites htoprc on quit, which against a writable stow link would churn the repo on every run.

Mounted ungated on every darwin host (see the [host-mounted modules pattern](../patterns/host-mounted-modules.md)), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/htop.nix`](../../modules/darwin/htop.nix)
