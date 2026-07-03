---
type: Darwin Module
title: Claude Account Selector
description: 'Kris'' profile-aware `claude` wrapper — mounted straight into host k''s configuration (the only consumer), not a shared flake.modules.darwin.* module.'
resource: modules/hosts/k/claude-account-selector/default.nix
tags: [darwin-module, host-mounted]
timestamp: '2026-07-03T10:23:09-07:00'
---

Kris' profile-aware `claude` wrapper — mounted straight into host k's configuration (the only consumer), not a shared flake.modules.darwin.* module. nix-darwin has no per-user xdg.configFile, so the generated zsh snippet — the host-specific rule/profile assignments prepended to the static wrapper.zsh — is built with writeText and linked into ~/.config/zsh during activation (the stowed ~/.config/zsh/.zshrc sources it when present). The desktop-app pin uses nix-darwin's launchd.user.agents.

Rationale: [Claude profile isolation](../decisions/claude-profile-isolation.md);
the generated rule preamble follows
[store-path-embedding configs](../patterns/store-path-configs.md).

Host-mounted feature ([k](../hosts/k.md)) — merged
straight into the hosts' configurations per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/k/claude-account-selector/default.nix`](../../modules/hosts/k/claude-account-selector/default.nix)
- README: [`modules/hosts/k/claude-account-selector/README.md`](../../modules/hosts/k/claude-account-selector/README.md)
