---
type: Darwin Module
title: Pam Tid Gate
description: pam-tid-gate ships its nix-darwin module with its sub-flake (./flakes/pam-tid-gate/darwin-module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module.
resource: modules/darwin/pam-tid-gate.nix
tags: [darwin-module, host-selective]
generated: { by: okflight/0.5.0, at: 2026-11-19T21:48:34+00:00 }
---

pam-tid-gate ships its nix-darwin module with its sub-flake (./flakes/pam-tid-gate/darwin-module.nix); re-export it into the Dendritic module set so hosts pick it up like any in-tree modules/darwin/* module. The module defaults security.pam-tid-gate.package to the sub-flake's own package, so no overlay is needed. Enable per host with `security.pam-tid-gate.enable = true;`.

Imported on every darwin host but disabled by default — hosts opt in with
`security.pam-tid-gate.enable = true;`
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).
Enabled on [SOC-Kris-Williams](../hosts/SOC-Kris-Williams.md).

When enabled, the sub-flake's module forces
`security.pam.services.sudo_local.touchIdAuth` off and appends the gate line
to `sudo_local.text` with `lib.mkAfter`. [core](core.md) writes `sudo_local`
straight through `environment.etc`, with a `pam_tid` line, so this file's glue
adds the `pam_reattach ignore_ssh` line with `lib.mkBefore` and forces
`environment.etc."pam.d/sudo_local".text` to `sudo_local.text` on gate hosts
only; other Macs keep core's file unchanged.
`security.pam-tid-gate.idleSeconds` (default 300) sets the idle rule. See
[pam-tid-gate](../packages/pam-tid-gate.md) and
[the decision](../decisions/sudo-touchid-gate.md).

## Source

- Module: [`modules/darwin/pam-tid-gate.nix`](../../modules/darwin/pam-tid-gate.nix)
- Options under: `security.pam-tid-gate`
