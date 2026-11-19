---
type: Decision
title: Gate sudo's Touch ID on Whether Anyone Can Reach the Readers
description: 'On the work MacBook, sudo used Touch ID even when nobody could touch its readers (hc or ssh from elsewhere, a locked screen, or Universal Control from k), so it waited on a prompt nobody could answer. OpenPAM cannot skip a module on a condition and macOS has no pam_exec, so a small PAM module (flakes/pam-tid-gate) stands in for pam_tid and returns PAM_IGNORE, sending sudo to the password, when any of five rules holds.'
resource: flakes/pam-tid-gate/
tags: [darwin, security, pam, sudo]
generated: { by: claude-code/opus-5.5, at: 2026-11-19T14:00:00-08:00 }
---

**Where:** [`flakes/pam-tid-gate/`](../../flakes/pam-tid-gate/) (module, CLI,
darwin module), enabled on [SOC-Kris-Williams](../hosts/SOC-Kris-Williams.md).
Related: [pam-tid-gate](../packages/pam-tid-gate.md),
[agent-remote](../modules/agent-remote.md).

## Context

`sudo_local` ran `pam_tid` on every Mac. Checked on the work MacBook
2026-11-19:

- hc terminals there run in the Aqua session (parent `hc --hc-launchd` under
  launchd) with no `SSH_*` variables, so `pam_reattach`'s `ignore_ssh` never
  applies and `sudo` puts the Touch ID prompt on the MacBook's screen.
- Only the MacBook's own reader answers it. A test prompt through Universal
  Control ignored the reader on k and on k's external keyboard.
- The MacBook stayed unlocked while Kris was away: display sleep was
  "prevented by UniversalControl", so the immediate lock never fired. A
  lock-only rule would have missed it.
- Universal Control input resets `HIDIdleTime` (0 s while typing through it),
  so an idle rule alone treats Universal Control as presence. UniversalControl
  holds a `com.apple.universalcontrol.preventDisplaySleep` power assertion
  whenever the Macs are linked, including while the cursor is on k.
- A plain ssh session through agent-remote descends from `sshd-session` and
  runs in launchd's System domain; hc does not descend from sshd at all.

## Decision

A PAM module, `pam_tid_gate.so`, takes `pam_tid`'s line. It returns
`PAM_IGNORE` (OpenPAM goes on to `pam_opendirectory`, the password) when
`sudo` runs under `sshd`/`sshd-session` or with `SSH_CONNECTION`,
`SSH_CLIENT` or `SSH_TTY` set (a tmux session started over ssh), the console
screen is locked, no
session is on the console, there has been no local input for 300 s, or the
Universal Control assertion is held. Otherwise it `dlopen`s
`/usr/lib/pam/pam_tid.so.2` and forwards `pam_sm_authenticate` and
`pam_sm_setcred`. It links no libpam (OpenPAM headers for types only), so the
system libpam `pam_tid` expects is the only one in `sudo`.

It ships as a sub-flake because it is original source that builds on its own
and has nothing repo-specific. agent-remote stayed in `modules/`: it is a
second sshd with a NixOS twin and no package, and the gate's ssh rule matches
any `sshd-session`.

Rejected:

- **Conditional control flags** (`[success=1 default=ignore]`): Linux-PAM only;
  OpenPAM has required/requisite/sufficient/binding/optional.
- **`pam_exec` with a check script**: macOS ships no `pam_exec`.
- **Rewriting `/etc/pam.d/sudo_local` on lock/unlock** from a daemon: racy,
  needs a GUI-session agent plus a root writer, and fights nix-darwin's
  ownership of the file.
- **Lock or idle alone**: both miss Universal Control (see Context).
- **A process-tree check alone**: misses hc, the usual way in.

## Consequences

- At home with Universal Control linked, `sudo` on the MacBook always asks
  for the password, also when typing on the MacBook itself.
- [core](../modules/core.md) still writes `sudo_local` through
  `environment.etc` (with a `pam_tid` line the gate's module can't remove), so
  the repo glue in `modules/darwin/pam-tid-gate.nix` forces the file to
  nix-darwin's `sudo_local.text` where the gate is on: the
  `pam_reattach ignore_ssh` line (`lib.mkBefore`), then the gate
  (`lib.mkAfter`). k and mini keep their file byte for byte, including the
  duplicate `pam_tid` line ahead of `pam_reattach`.
- On the gate host `pam_reattach` now runs on every `sudo`, where before a
  successful first `pam_tid` skipped it. pam_reattach 1.3's `ignore_ssh` loop
  reads past its three-entry array (`sizeof` instead of the element count);
  a review found the overrun lands on zeroed data in the current build, so it
  is harmless there but would need a patch if a rebuild changed the layout.
- Bad module options fall back to defaults (all rules, `idle=300`), and a
  parent process that can't be read counts as `sshd`, so errors lean toward
  the password.
- The prompt path can only be tested through real `sudo`: `pam_tid` asks
  `authd` for `com.apple.security.sudo`, whose rule is
  `entitled` + `authenticate-session-owner`, and a test binary is not entitled
  (`-60005`). Tested without sudo: every rule from hc and ssh, lock and
  unlock (switched within one 2 s sample), and the forward into `pam_tid` up
  to `authd`.
- Not verified: the Universal Control assertion's absence when the Macs are
  not linked (at the office), and the `console` rule at the login window.
