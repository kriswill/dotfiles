---
type: Flake-parts Module
title: Lib
description: 'Exposes the nixpkgs lib extended with this repo''s pure helpers (`mkProgramOption`, `kanagawa`) as a top-level option, so both the darwin and home-manager evaluations can receive it via specialArgs / extraSpecialArgs.'
resource: modules/lib.nix
tags: [flake-parts]
timestamp: '2026-05-24T19:25:21-07:00'
---

Exposes the nixpkgs lib extended with this repo's pure helpers (`mkProgramOption`, `kanagawa`) as a top-level option, so both the darwin and home-manager evaluations can receive it via specialArgs / extraSpecialArgs.

Plumbing layer of the flake — see the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/lib.nix`](../../modules/lib.nix)
