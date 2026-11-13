---
type: Decision
title: Prioritize Mini's Agent Services and Suppress Session Restoration
description: 'Use normal launchd scheduling for mini''s primary agents and suppress optional GUI restoration without removing the logged-in desktop.'
tags: [darwin, mini, boot, performance]
status: stable
generated: { by: codex/gpt-6, at: 2026-11-13T14:43:17-08:00 }
sources:
  - id: startup-manual
    resource: ../../docs/shell-startup-performance.md
    title: Measured boot timeline and startup controls
---

## Context

[mini](../hosts/mini.md) is primarily a headless agent host with a desktop
session for GUI automation. Generation 26 provided SSH/hc at +16 s, but
signing at about +61 s and Hermes gateway initialization at +72.6 s.
Both jobs used launchd's `Background` classification. Helium/Ghostty were
restored at +10 s and 1Password's login launcher also ran.[^startup-manual]

## Decision

Override [Hermes](../modules/mini-hermes-agent.md) and
[signing](../modules/git-signing-agent.md) to `Standard` on mini alone.
Instrument signing's native bootstrap and loader phases; use Hermes's
existing startup-completion log. Keep store mounting, sops and the short
boot activation early.

Use a separate [headless login policy](../modules/headless-login.md) to
block session-wide GUI restoration. The initial implementation also disabled
1Password's login launcher. That part was based on an incorrect reading of
the requirement and is superseded: **1Password should launch normally**;
startup and autonomous agent workflows must not require interactive desktop
authentication. Remove the launcher-disable action in a future configuration
change, keeping desktop login and restoration suppression. This follow-up
corrected documentation only; the implementation still contains that action.

## Consequences

Generation 28's cold boot reached the Hermes initialization marker at
+28.413 s (generation 26: +72.647 s), and loaded the signing key at about
+30 s (previously about +61 s). Incoming SSH and local Core startup remained
around +14–16 s. Both changes were applied before reboot, so this single
comparison does not isolate scheduling from restoration or ordinary boot
variation. Generation 27's two-second signing and roughly three-second
Hermes results were warm restarts, not cold-boot measurements.

Restoration suppression worked. ServiceManagement re-enabled 1Password's
launcher and the app started normally, which satisfies the clarified launch
requirement; it does not establish that a password dialog appeared or did
not appear. The signing loader and machine SSH checks succeeded without
desktop authentication. General agent vault access remains separate and is
not provisioned by the root-only signing token; see
[Mini's credential boundary](../modules/mini-hermes-agent.md).

The restoration flag is present in this macOS build but undocumented;
verify it after OS updates. Persistent defaults and launchd disable state
need explicit rollback, described in the module doc. No blanket removal of
Apple services or permission changes is part of this decision.

[^startup-manual]: Generation-26 logs, live launchd inventory and local macOS manual/binary inspection.
