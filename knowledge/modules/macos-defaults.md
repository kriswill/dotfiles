---
type: Darwin Module
title: Macos Defaults
description: 'nix-darwin user and system defaults for the Macs: traditional scroll direction, drag windows with ctrl+cmd+click, fn key does nothing, and a Dock that auto-hides without being restarted on every switch.'
resource: modules/darwin/macos-defaults.nix
tags: [darwin-module]
generated: { by: okflight/0.4.0, at: 2026-05-24T22:21:04-07:00 }
---

Sets a handful of macOS defaults, all `mkDefault` so a host can override
them:
- `NSGlobalDomain` scroll direction and `NSWindowShouldDragOnGesture`;
- `hitoolbox.AppleFnUsageType`;
- Dock `autohide`.

The Dock setting deliberately avoids `system.defaults.dock`. nix-darwin kills
the Dock on every activation whenever any `system.defaults.dock` option is
set (`defaults-write.nix`, `length dock > 0`), so each switch made the Dock
blink even when nothing changed. `autohide` is written through
`CustomUserPreferences."com.apple.dock"` instead, which sets the same key with
no restart. A `preActivation`/`postActivation` pair exports the
`com.apple.dock` domain (as the user, in their launchd session) before and
after activation, and restarts the Dock only when the export differs. Setting
any `system.defaults.dock` option anywhere brings the unconditional restart
back.

Mounted ungated on every darwin host (see the [host-mounted modules pattern](../patterns/host-mounted-modules.md)), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/macos-defaults.nix`](../../modules/darwin/macos-defaults.nix)
