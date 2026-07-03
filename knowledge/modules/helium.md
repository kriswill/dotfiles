---
type: NixOS Module
title: Helium
description: 'Helium browser — enables the upstream programs.helium module and declares a root-owned Chromium managed policy in /etc (privacy baseline, DuckDuckGo, force-installed extensions).'
resource: modules/nixos/helium/default.nix
tags: [nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

Two sibling files merge into the one deferredModule
`flake.modules.nixos.helium`. `default.nix` enables the upstream
`programs.helium` module and records what is *not* declaratively manageable
(per-extension keyboard shortcuts live only in the mutable profile
Preferences). `policies.nix` carries the substance: a Chromium managed-policy
file written via `environment.etc."chromium/policies/managed/helium.json"` —
unbranded-Chromium Helium reads `/etc/chromium/policies/managed/*.json` even
with `programs.chromium.enable = false`, and the file must be root-owned or
it is ignored. Policies are read only at Helium startup (restart to apply);
verify at `chrome://policy`.

Policy content: privacy baseline (metrics, background mode, safe-browsing
reporting, and URL-keyed collection off), `RestoreOnStartup = 1`, DuckDuckGo
as default search, and an `ExtensionInstallForcelist` for Dark Reader +
1Password (uBlock Origin deliberately excluded — it's built into Helium).
Mutable browser state beyond policy reach is handled by the separate
`config/` snapshot system — see [users-k-helium](users-k-helium.md).

Mounted ungated on every NixOS host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/nixos/helium/default.nix`](../../modules/nixos/helium/default.nix)
- Policies: [`modules/nixos/helium/policies.nix`](../../modules/nixos/helium/policies.nix)
- Manual: [`docs/helium.md`](../../docs/helium.md)
