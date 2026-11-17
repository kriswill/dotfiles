---
type: Darwin Module
title: Agent Remote
description: 'A second OpenSSH server run as its own launchd daemon on a configurable port (default 2122), accepting public keys only and independent of the macOS Remote Login switch.'
resource: modules/darwin/agent-remote.nix
tags: [darwin-module, ssh, host-selective]
generated: { by: claude/fable-5.2, at: 2026-11-16T21:46:44-08:00 }
sources:
  - id: sshd-man
    resource: https://man.openbsd.org/sshd.8
    title: sshd(8), the -D, -e, -p and -o flags
  - id: darwin-options
    resource: https://nix-darwin.github.io/nix-darwin/manual/
    title: nix-darwin option reference (launchd.daemons)
---

The built-in sshd (`system/com.openssh.sshd`, port 22) is left as macOS or
[Remote Login](remote-login.md) has it. This module adds a separate launchd
daemon, `org.nixos.agent-remote`,[^darwin-options] that runs the same
`/usr/sbin/sshd` in the foreground on `services.agent-remote.port`. Turning
Remote Login off in the Sharing pane does not stop it.

It reads the stock `/etc/ssh/sshd_config`, so it shares the host keys and the
authorized keys that [darwin core](core.md) declares; a client sees the same
host identity on both ports. The differences are `-o` flags on the command
line, which override the file:[^sshd-man]

- the port (`-p`), default 2122;
- `PasswordAuthentication=no` and `KbdInteractiveAuthentication=no`, so only
  public keys are accepted, where port 22 still allows passwords;
- `PidFile=none`.

`UsePAM` stays on, so the `com.apple.access_ssh` service ACL still decides
who may log in, with the failure mode described under
[Remote Login](remote-login.md).

The daemon runs `ssh-keygen -A` before sshd. That creates only missing host
keys, which matters on a Mac where Remote Login has never been on: macOS
generates them on the first port-22 connection, not at install.

Imported on every darwin host but disabled by default (the
[host-mounted modules pattern](../patterns/host-mounted-modules.md));
enabled on [k](../hosts/k.md), [mini](../hosts/mini.md) and
[SOC-Kris-Williams](../hosts/SOC-Kris-Williams.md). Output goes to `/var/log/agent-remote.log`.
The macOS application firewall, when on, may need to allow incoming
connections for sshd on the new port.

## Source

- Module: [`modules/darwin/agent-remote.nix`](../../modules/darwin/agent-remote.nix)
- Options under: `services.agent-remote`

[^sshd-man]: sshd(8): `-o` gives options in configuration-file format; `-p` overrides any `Port` in the file.
[^darwin-options]: nix-darwin `launchd.daemons.<name>`: a system launchd job labelled `org.nixos.<name>`.
