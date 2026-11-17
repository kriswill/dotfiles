---
type: Darwin Module
title: Remote Login
description: 'macOS Remote Login (the built-in sshd) re-enabled on each activation, with user k kept in the SSH service ACL group, so the work Mac stays reachable from the home network.'
resource: modules/darwin/remote-login.nix
tags: [darwin-module, ssh, host-selective]
generated: { by: claude/fable-5.2, at: 2026-11-16T20:25:00-08:00 }
sources:
  - id: darwin-options
    resource: https://nix-darwin.github.io/nix-darwin/manual/
    title: nix-darwin option reference (services.openssh.enable)
---

Two separate macOS switches gate an inbound SSH login, and this module
re-applies both on every [nrs](nrs.md) activation:

1. **The sshd launchd job.** The module sets nix-darwin's
   `services.openssh.enable = true`, whose activation step enables and
   bootstraps `system/com.openssh.sshd` when Remote Login reports
   Off.[^darwin-options] Hosts that leave the module off keep the option at
   `null`, meaning macOS manages sshd.
2. **The service ACL group `com.apple.access_ssh`.** While that group
   exists, `pam_sacl` admits only its members. A non-member's public key is
   accepted and the connection is then closed; the client sees only
   `Connection closed`, and the reason (`pam_sacl: denying 'k' due to failed
   service ACL check`) is in the server's unified log. A `postActivation`
   step adds each of `services.remote-login.users` (default `k`) with
   `dseditgroup` when missing. "Allow access for: All users" renames the
   group to `com.apple.access_ssh-disabled`, so a missing group is left
   alone.

Imported on every darwin host but disabled by default (the
[host-mounted modules pattern](../patterns/host-mounted-modules.md));
enabled only on [SOC-Kris-Williams](../hosts/SOC-Kris-Williams.md). On
2026-11-16 that Mac turned Remote Login off and restored the ACL group
without `k` within minutes of both being set by hand; what resets them is
not identified. The module is deliberately activation-time only: it does not
run on a timer and does not contend with whatever resets the state between
rebuilds.

The authorized keys come from [darwin core](core.md). From the home network
the Mac is addressed as `work`, a local DNS record on the UniFi gateway for
its Work-VLAN address: its mDNS name resolves to `::1` there. `work` is in
[`lib/ssh-machines.nix`](../../lib/ssh-machines.nix), so
[k](ssh-client.md) connects with its machine key and [Herdr](herdr.md) can
reach it without a 1Password prompt. The gateway's firewall must also allow
Home to the Mac's port 22; that rule and the DNS record live on the gateway,
not in this repo.

`/usr/bin/log` must be called by path to read the sshd log from zsh, whose
`log` builtin shadows it.

## Source

- Module: [`modules/darwin/remote-login.nix`](../../modules/darwin/remote-login.nix)
- Options under: `services.remote-login`

[^darwin-options]: nix-darwin `services.openssh.enable`: `null` leaves sshd to macOS; `true` enables and bootstraps `com.openssh.sshd` on activation.
