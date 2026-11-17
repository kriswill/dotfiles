---
type: Dual Module
title: Agent Remote
description: 'A second OpenSSH server on port 2122 on every managed machine, run as its own launchd daemon (macOS) or systemd unit (nebula), accepting public keys only and independent of the main sshd and the macOS Remote Login switch.'
resource: modules/darwin/agent-remote.nix
tags: [darwin-module, nixos-module, ssh, host-selective]
generated: { by: claude/fable-5.2, at: 2026-11-16T21:46:44-08:00 }
sources:
  - id: sshd-man
    resource: https://man.openbsd.org/sshd.8
    title: sshd(8), the -D, -e, -p and -o flags
  - id: darwin-options
    resource: https://nix-darwin.github.io/nix-darwin/manual/
    title: nix-darwin option reference (launchd.daemons)
  - id: nixos-options
    resource: https://search.nixos.org/options?query=systemd.services
    title: NixOS option reference (systemd.services, networking.firewall)
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
The macOS application firewall did not block the port on SOC-Kris-Williams,
where it is on with stealth mode.

Reaching SOC-Kris-Williams from the home network also needs a rule on the
UniFi gateway, which is not in this repo: the zone policy
`Agent Remote Home -> Work` allows TCP 2122 from the Home network to
`10.4.0.12`, beside `SSH Home -> Work` for port 22. Without it the
connection times out.

## Twin differences

[nebula](../hosts/nebula.md) runs the same second sshd from
`modules/nixos/agent-remote.nix`, per the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md), so
[Herdr](herdr.md) reaches every managed machine on port 2122. What differs:

- **A systemd unit, `agent-remote.service`**, not a launchd daemon.[^nixos-options]
  It copies `sshd.service`'s settings: `Type=notify-reload`,
  `KillMode=process` (a restart leaves logged-in sessions alone) and
  `Restart=always`. It restarts when the generated `sshd_config` changes.
- **Logs go to the journal** (`journalctl -u agent-remote`), not to a file.
- **No `ssh-keygen -A`.** The unit is ordered after NixOS's
  `sshd-keygen.service`, which creates the host keys.
- **The firewall port is opened by the module.** nebula's firewall is on and
  `services.openssh.openFirewall` covers only `services.openssh.ports`.
- **Same options, one extra check.** `services.agent-remote.enable` and
  `.port` exist in both classes, off by default; nebula turns it on in
  [nebula-agent-remote](nebula-agent-remote.md). An assertion requires
  `services.openssh.enable`, whose `/etc/ssh/sshd_config`, `sshd` user and
  host keys the unit reuses.
- **The password flags change nothing today.** snowglobe-factory already
  makes nebula's port 22 key-only; the flags keep 2122 so regardless.
  There is no service ACL group on Linux, so any user with an authorized
  key may log in, as on port 22.

Checked on nebula before the first rebuild: `sshd -G` with these flags
reports `Port 2122` on both address families (the file's `Port 22` is
overridden) and `PidFile none`.

## Source

- Module: [`modules/darwin/agent-remote.nix`](../../modules/darwin/agent-remote.nix)
- NixOS module: [`modules/nixos/agent-remote.nix`](../../modules/nixos/agent-remote.nix)
- Options under: `services.agent-remote` (both classes)

[^sshd-man]: sshd(8): `-o` gives options in configuration-file format; `-p` overrides any `Port` in the file.
[^darwin-options]: nix-darwin `launchd.daemons.<name>`: a system launchd job labelled `org.nixos.<name>`.
[^nixos-options]: NixOS `systemd.services.<name>` defines a system unit; `networking.firewall.allowedTCPPorts` lists the ports the firewall accepts.
