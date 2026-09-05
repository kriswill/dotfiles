---
type: Darwin Module
title: Claude Account Selector
description: 'zsh wrapper that auto-selects a Claude Code account/profile by launch directory, with per-profile config-dir isolation.'
resource: modules/darwin/claude-account-selector/default.nix
tags: [darwin-module]
generated: { by: okflight/0.4.0, at: 2026-07-03T10:23:09-07:00 }
---

zsh wrapper that auto-selects a Claude Code account/profile by launch
directory, so a personal and a corporate account coexist on one machine.
Rationale: [Claude profile isolation](../decisions/claude-profile-isolation.md);
the generated rule preamble follows
[store-path-embedding configs](../patterns/store-path-configs.md).

Imported on every darwin host but disabled by default — hosts opt in with
`programs.claude-account-selector.enable = true;` (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)); auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

Profile isolation means anything that installs into a Claude config dir must
be repeated per profile with `CLAUDE_CONFIG_DIR` set — e.g.
[rtk](rtk.md)'s `rtk init -g` hook registration. It also shapes how
user-level Claude *skills* deploy: the fallback `~/.claude -> ~/.claude-me`
symlink is unowned by stow, so skills ship as
[split stow packages](../decisions/claude-skills-split-stow-packages.md)
(`home/claude/` for nixos, `home/claude-me/` for the macs).

## Source

- Module: [`modules/darwin/claude-account-selector/default.nix`](../../modules/darwin/claude-account-selector/default.nix)
- Options under: `programs.claude-account-selector`
- README: [`modules/darwin/claude-account-selector/README.md`](../../modules/darwin/claude-account-selector/README.md)
