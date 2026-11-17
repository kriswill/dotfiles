---
type: Dual Module
title: Agent Remote
description: 'A second OpenSSH server on port 2122 on every managed machine, run as its own launchd daemon (macOS) or systemd unit (nebula), accepting public keys only and independent of the main sshd and the macOS Remote Login switch.'
resource: modules/darwin/agent-remote.nix
tags: [darwin-module, nixos-module, ssh, host-selective]
generated: { by: codex/gpt-6, at: 2026-11-16T22:21:11-08:00 }
sources:
  - id: sshd-man
    resource: https://man.openbsd.org/sshd.8
    title: sshd(8), foreground execution and configuration selection
  - id: sshd-config-man
    resource: https://man.openbsd.org/sshd_config.5
    title: sshd_config(5), authentication and key configuration
  - id: darwin-options
    resource: https://nix-darwin.github.io/nix-darwin/manual/
    title: nix-darwin option reference (launchd.daemons)
  - id: nixos-options
    resource: https://search.nixos.org/options?query=systemd.services
    title: NixOS option reference (systemd.services, networking.firewall)
---

## macOS daemon

`org.nixos.agent-remote` runs **nixpkgs OpenSSH** (`pkgs.openssh`) in the
foreground under launchd,[^darwin-options] using its own immutable Nix-store
configuration via `sshd -f`.[^sshd-man] It does not read Apple's
`/etc/ssh/sshd_config` or its drop-ins. Changes to the package, port or config
change the launchd command's store path so activation reloads the job.

`AuthenticationMethods publickey` explicitly requires a public key; password,
keyboard-interactive and empty-password authentication are disabled.[^sshd-config-man]
The nixpkgs Darwin build has no PAM support: the macOS Remote Login switch
and `com.apple.access_ssh` ACL do not control this server. Access is determined
by SSH keys and OpenSSH's own account checks. Apple-only PAM session hooks do
not run. [Remote Login](remote-login.md) continues to manage Apple's port-22
server independently.

The daemon shares `services.openssh.hostKeys` with port 22, preserving the
machine's SSH identity. nix-darwin's OpenSSH activation creates missing keys
before starting launchd jobs, even when `services.openssh.enable` is unset or
false. An empty host-key list is rejected. The service itself never generates
or replaces keys.

Both `~/.ssh/authorized_keys` and the declarative keys from
[darwin core](core.md) remain accepted. The latter use nix-darwin's
`AuthorizedKeysCommand /bin/cat /etc/ssh/nix_authorized_keys.d/%u` reader as
`_sshd`, which handles the Nix-managed symlinks. SFTP uses `internal-sftp`
from the packaged server; locale forwarding accepts `LANG` and `LC_*`.

Imported on every darwin host but disabled by default (the
[host-mounted modules pattern](../patterns/host-mounted-modules.md));
enabled on [k](../hosts/k.md), [mini](../hosts/mini.md) and
[SOC-Kris-Williams](../hosts/SOC-Kris-Williams.md). The port defaults to 2122;
output goes to `/var/log/agent-remote.log`. Local loopback tests do not verify
macOS application-firewall access from another machine for this new binary.

Reaching SOC-Kris-Williams from the home network also needs a rule on the
UniFi gateway, which is not in this repo: the zone policy
`Agent Remote Home -> Work` allows TCP 2122 from the Home network to
`10.4.0.12`, beside `SSH Home -> Work` for port 22. Without it the
connection times out.

## Verification (2026-11-16)

`nrs --dry` built and validated k; all three Darwin hosts evaluate to the new
command. An unprivileged loopback test with the packaged OpenSSH 10.6p1 and
generated config passed command execution with k's existing machine key,
internal SFTP, unknown-key rejection, and publickey-only method negotiation.
That test added a disposable host key and ran `AuthorizedKeysCommand` as k;
it did not exercise root-owned host keys or the production `_sshd` reader.
Root testing needed interactive sudo authentication. The launchd service has
not been activated; run `nrs` on each Mac to deploy.

## Twin differences

[nebula](../hosts/nebula.md) runs a second sshd from
`modules/nixos/agent-remote.nix`, per the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md), so
[Herdr](herdr.md) reaches every managed machine on port 2122. What differs:

- **Shares the main server's binary and config.** Unlike macOS, it uses
  `services.openssh.package` and `/etc/ssh/sshd_config`, with command-line
  overrides for the port, pid file and password authentication.
- **A systemd unit, `agent-remote.service`**, not a launchd daemon.[^nixos-options]
  It copies `sshd.service`'s settings: `Type=notify-reload`,
  `KillMode=process` (a restart leaves logged-in sessions alone) and
  `Restart=always`. It restarts when the generated `sshd_config` changes.
- **Logs go to the journal** (`journalctl -u agent-remote`), not to a file.
- **Host-key generation uses a unit.** The service is ordered after NixOS's
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

[^sshd-man]: sshd(8): `-D` stays in the foreground, `-e` logs to stderr, and `-f` selects the configuration file.
[^sshd-config-man]: sshd_config(5): `AuthenticationMethods publickey` requires public-key authentication; `AuthorizedKeysCommand` supplements `AuthorizedKeysFile`.
[^darwin-options]: nix-darwin `launchd.daemons.<name>`: a system launchd job labelled `org.nixos.<name>`.
[^nixos-options]: NixOS `systemd.services.<name>` defines a system unit; `networking.firewall.allowedTCPPorts` lists the ports the firewall accepts.
