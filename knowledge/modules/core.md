---
type: Darwin Module
title: Core
description: 'The always-on darwin system baseline shared by every host — stateVersion, primary user, baseline packages, touch-ID sudo, fonts, shell enables, nix/nixpkgs settings.'
resource: modules/darwin/core.nix
tags: [darwin-module]
generated: { by: codex/gpt-6, at: 2026-11-13T11:25:04-08:00 }
sources:
  - id: darwin-options
    resource: https://nix-darwin.github.io/nix-darwin/manual/
    title: nix-darwin configuration options
---

The always-on darwin system baseline shared by every host: stateVersion,
primary user, baseline packages (iproute2mac, pstree, glow,
codebase-memory-mcp CLI), touch-ID sudo (pam-reattach), fonts, fish/zsh
enables, `nix.enable = false` (Determinate owns nix), and
`allowUnfree = false` with a per-package `allowUnfreePredicate` list
([unfree-default-deny](../decisions/unfree-default-deny.md); first entry `p4v`,
see [p4v-nix-apps-dont-strip](../decisions/p4v-nix-apps-dont-strip.md)).
The rebuild helpers live in [nrs](nrs.md).

Every Mac authorizes both the existing personal SSH key and
[mini's machine key](ssh-client.md) for `k`, using
`users.users.k.openssh.authorizedKeys.keyFiles` for the latter.[^darwin-options]
This includes the offline [work Mac](../hosts/SOC-Kris-Williams.md) on its
next rebuild; adding trust never replaces the personal key.

Mounted ungated on every darwin host (see the [host-mounted modules pattern](../patterns/host-mounted-modules.md)), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/core.nix`](../../modules/darwin/core.nix)

[^darwin-options]: `users.users.<name>.openssh.authorizedKeys` accepts literal keys and public-key files.
