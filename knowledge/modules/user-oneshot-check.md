---
type: NixOS Module
title: User Oneshot Check
description: 'Evaluation warning for the user units that hung `nrs` on 2026-10-24: a oneshot that nothing starts at login (a path unit, a timer or a person starts it), that does not stay active, and that a switch would still restart.'
resource: modules/nixos/user-oneshot-check.nix
tags: [nixos-module]
generated: { by: claude-code/opus-5.5, at: 2026-10-24T20:55:00-07:00 }
---

Adds a NixOS `warnings` entry for each user service that matches all of:
- enabled;
- `Type=oneshot`;
- no `RemainAfterExit` (it accepts systemd's string spellings such as
  `"yes"`);
- `restartIfChanged` still true;
- an empty `wantedBy`, so a path unit, a timer or a person starts it, not
  the login.

That is the shape of unit that hung `nrs` on 2026-10-24. switch-to-configuration-ng
restarts changed user units, `activating` ones included, and waits on
those jobs with no timeout. It does that before it restarts the system
services it stopped, so one capture mid-sleep holds the network down until
it exits. The warning prints while the system evaluates (as `evaluation
warning:` in `nrs2`'s and nom's output), before anything changes. The rule
it enforces and the incident are in
[Keep Long-Running User Oneshots Out of the Switch's Restart Set](../decisions/user-oneshots-skip-switch-restart.md).

Silent on [nebula](../hosts/nebula.md) today, upstream units included. The
other user oneshots there, `flatpak-repo` and `nixos-activation`, start at
login and stay active. Verified by evaluating with one capture unit's
`restartIfChanged` forced back on, plus a bare test oneshot. Both were named,
and a test oneshot with `RemainAfterExit = "yes"` was not.

Mounted ungated on every NixOS host
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/nixos/user-oneshot-check.nix`](../../modules/nixos/user-oneshot-check.nix)
