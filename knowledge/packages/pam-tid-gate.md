---
type: Sub-flake
title: pam-tid-gate
description: 'pam-tid-gate — Touch ID for sudo only while someone can reach this Mac''s own readers.'
resource: flakes/pam-tid-gate/
tags: [sub-flake, package]
generated: { by: okflight/0.5.0, at: 2026-11-19T21:48:34+00:00 }
---

pam-tid-gate — Touch ID for sudo only while someone can reach this Mac's own readers.

Consumed by the root flake as a relative-path input — see the
[sub-flake extraction pattern](../patterns/subflake-extraction.md).

`pam_tid_gate.so` goes where `pam_tid.so` would in `/etc/pam.d/sudo_local`.
It sends `sudo` to the password (returns `PAM_IGNORE`) under `sshd`, at a
locked screen, with no console session, after `idle=` seconds without local
input, or while Universal Control is linked, and otherwise forwards to Apple's
`pam_tid`. `pam-tid-gate` prints the current decision and the rules behind it.
Why and how it was tested:
[the decision](../decisions/sudo-touchid-gate.md). The darwin module is
re-exported by [modules/darwin/pam-tid-gate](../modules/pam-tid-gate.md).

## Source

- Flake: [`flakes/pam-tid-gate/`](../../flakes/pam-tid-gate/)
- README: [`flakes/pam-tid-gate/README.md`](../../flakes/pam-tid-gate/README.md)
