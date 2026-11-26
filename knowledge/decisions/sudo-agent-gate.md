---
type: Decision
title: Gate nebula's 1Password sudo Step Behind a 2-Second Signing Probe
description: 'A pam_exec rule right before pam_ssh_agent_auth signs a probe through the same agent with a 2-second limit and skips the agent step when it fails, so sudo on nebula goes on to the password (the herdr-askpass dialog for an agent) instead of waiting 60 s behind a 1Password dialog nobody can see.'
tags: [nixos, sudo, pam, 1password, herdr]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-11-26T15:30:00-08:00 }
sources:
  - id: pam-exec
    resource: https://man7.org/linux/man-pages/man8/pam_exec.8.html
    title: 'pam_exec(8): quiet, seteuid, and the environment it passes'
---

**Where:** [sudo-1password](../modules/sudo-1password.md)
(`modules/hosts/nebula/sudo-1password.nix`); pairs with
[herdr-askpass](herdr-askpass-sudo-where-you-are.md), the password dialog
sudo falls through to.

## Context

nebula's sudo authenticates through 1Password's ssh agent first
(`pam_ssh_agent_auth`, sufficient), then the password. With 1Password
unlocked and sudo approved, the agent answers at once. Locked, or for a
program it hasn't approved, 1Password shows a dialog on nebula's screen and
holds the request for exactly 60 s (measured: `Error reading response length
from authentication socket` 60.0 s after the request). Working from k, that
dialog is out of sight, and an agent's sudo waited a minute before the
herdr-askpass dialog appeared.

`pam_ssh_agent_auth` has no timeout. Listing keys (`ssh-add -l`) can't tell
locked from unlocked: 1Password answers it while locked. Only a signature
shows whether the agent would answer.

## Decision

`sudo-agent-gate` runs from `pam_exec` (`quiet seteuid`, so as root) at the
agent rule's order minus one, with `[success=ignore default=1]`.[^pam-exec]
It reads `SSH_AUTH_SOCK` from sudo's own environment (`/proc/$PPID/environ`;
pam_exec passes only PAM's), then signs a probe with the authorized key's
public half through that agent, as the user (`setpriv`), with
`timeout -k 1 2`. Success: sudo goes on to `pam_ssh_agent_auth`, which signs
for real. Failure: `default=1` skips exactly that rule, and `pam_unix` asks
for the password: on a terminal, or through herdr-askpass for an agent. A
skip is logged under `sudo-agent-gate` in the journal.

The gate never authenticates anyone. A broken gate can only send sudo to the
password (or, if it always succeeded, behave as before), so it can't lock
you out or let anyone in.

## Consequences

- Locked 1Password: sudo reaches the password after about 2 s instead of
  60 s. The 1Password dialog the probe raised stays on nebula's screen until
  its own 60 s end.
- 1Password approves programs separately, and the probe is `ssh-keygen`.
  After each approval period (1Password's "remember" setting), the probe
  needs one Authorize. Until then sudo goes to the password after 2 s even
  though 1Password is unlocked.
- If the probe is approved and sudo isn't, sudo can still wait 60 s on
  1Password's Authorize for sudo.
- Unlocked and approved, each sudo signs twice (the probe, then the real
  check), both without prompts.

[^pam-exec]: pam_exec(8), options `quiet` and `seteuid`, and the environment it passes
