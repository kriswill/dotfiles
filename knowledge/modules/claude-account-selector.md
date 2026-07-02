---
type: Darwin Module
title: Claude Account Selector
description: zsh wrapper that auto-selects a Claude Code account/profile by launch directory, with per-profile config-dir isolation.
resource: modules/darwin/claude-account-selector/default.nix
tags: [darwin-module]
timestamp: '2026-06-28T19:42:52-07:00'
---

zsh wrapper that auto-selects a Claude Code account/profile by launch
directory, so a personal and a corporate account coexist on one machine.
Rationale: [Claude profile isolation](../decisions/claude-profile-isolation.md);
the generated rule preamble follows
[store-path-embedding configs](../patterns/store-path-configs.md).

Follows the [module option pattern](../patterns/module-option-pattern.md), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/claude-account-selector/default.nix`](../../modules/darwin/claude-account-selector/default.nix)
- Options under: `kriswill.claude-account-selector`
- README: [`modules/darwin/claude-account-selector/README.md`](../../modules/darwin/claude-account-selector/README.md)
