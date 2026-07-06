---
type: Reference
title: Nix Language
description: 'The lazy, pure, functional DSL every .nix file here is written in — evaluated by Determinate Nix, authored in dendritic idioms, kept clean by deadnix/statix/nixfmt and nil_ls.'
tags: [nix, language]
timestamp: '2026-07-04T00:00:00-07:00'
---

The [Nix language](https://nix.dev/manual/nix/stable/language/) is a
domain-specific, declarative, pure, lazy, dynamically typed functional
language designed for composing derivations — precise descriptions of how
existing files are used to derive new files. Every `.nix` file in this
repository is written in it.

## How this repo uses it

- **Evaluator:** all hosts run Determinate Nix — chosen because the
  `./flakes/*` relative-path sub-flake inputs need Nix ≥ 2.26's path-input
  locking, which Lix lacked (see
  [Replace Lix With Determinate Nix](decisions/lix-to-determinate.md)).
- **Laziness as a feature:** the single `flake.overlays` set applies to
  both OSes because one-OS overlays either guard internally or only *add*
  attrs the other OS never evaluates — a rule that only works in a lazy
  language ([`AGENTS.md`](../AGENTS.md), Overlays).
- **Idioms:** every file is an attrset-merging flake-parts module (the
  [Dendritic module layout](patterns/dendritic-modules.md)); package lists
  use `builtins.attrValues { inherit (pkgs) …; }`; override-prone scalars
  in universal modules take `lib.mkDefault`. House style is codified in
  [`AGENTS.md`](../AGENTS.md).
- **Tooling:** the [dev](modules/dev.md) shell carries the lint/format
  chain — deadnix (dead bindings), statix (anti-patterns), nixfmt via
  `nix fmt` (nixfmt-tree). Editing goes through nil_ls (see
  [nvim LSP](nvim/lsp.md)), which formats with the same nixfmt and ignores
  `unused_binding`/`unused_with` — dendritic modules legitimately keep
  unused args.

## Citations

- [Nix Reference Manual — language chapter](https://nix.dev/manual/nix/stable/language/)
- [nix.dev tutorial: Nix language basics](https://nix.dev/tutorials/nix-language)
- [noogle.dev](https://noogle.dev) — searchable Nix function/API reference
