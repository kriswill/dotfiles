---
type: Darwin Module
title: Slack Leave Devopsinc
description: 'Installs the slack-leave-devopsinc package system-wide on every Mac, so the CLI is on PATH and "Leave devopsinc Channels" is launchable from Spotlight.'
resource: modules/darwin/slack-leave-devopsinc.nix
tags: [darwin-module, slack]
generated: { by: claude-code/2.1.287, at: 2026-10-02T17:18:13+00:00 }
sources:
  - id: nix-darwin-applications
    resource: https://github.com/lnl7/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/system/applications.nix
    title: nix-darwin applications module (systemPackages → /Applications/Nix Apps)
---

Adds [`pkgs.slack-leave-devopsinc`](../packages/slack-leave-devopsinc.md) to
`environment.systemPackages`. It has to be `systemPackages`, **not**
`users.users.k.packages` like most CLIs in
[user-packages](user-packages.md): nix-darwin builds `/Applications/Nix Apps`
only from `systemPackages`' `Applications/` and rsync-copies the bundles there
as real directories (`--copy-unsafe-links`), which is what lets Spotlight
index "Leave devopsinc Channels".[^nix-darwin-applications] The copied app's
binary wrapper execs the CLI by absolute store path, which the system closure
keeps alive.

Mounted ungated on every darwin host, not just SOC-Kris-Williams (Kris' call:
all Macs). Without a token in the Keychain the tool just fails with a
notification. See the [host-mounted modules pattern](../patterns/host-mounted-modules.md)
and the [Dendritic module layout](../patterns/dendritic-modules.md); rationale
in the [decision record](../decisions/slack-leave-devopsinc-api.md).

## Source

- Module: [`modules/darwin/slack-leave-devopsinc.nix`](../../modules/darwin/slack-leave-devopsinc.nix)

[^nix-darwin-applications]: nix-darwin applications module (systemPackages → /Applications/Nix Apps)
