---
type: Dual Module
title: Ssh Private Hosts
description: Deploys the sops-encrypted private ssh Host entries (one shared file, modules/hosts/ssh-hosts.yaml) to ~/.ssh/config.d/private-hosts, where the public stow ssh config Include-globs them.
resource: modules/darwin/ssh-private-hosts.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-11T21:42:47+00:00'
---

Both twins declare the same [sops](sops.md) secret from the **shared**
`modules/hosts/ssh-hosts.yaml` (recipients: [k](../hosts/k.md) +
[nebula](../hosts/nebula.md) — either host's age key edits it) with
`owner = "k"` (ssh reads it as the user; the root-owned default is
unreadable) and a per-OS `path` under `~/.ssh/config.d/`. The stow-managed
`~/.ssh/config` (`home/ssh`, cross-platform since 2026-07-11: relative
`Include config.d/*`, per-OS 1Password `IdentityAgent` via
`Match exec uname`) picks the file up through its Include glob. Rationale
and history: [ssh-private-hosts decision](../decisions/ssh-private-hosts.md).

The nixos twin also adds `systemd.tmpfiles.rules` creating
`~/.ssh{,/config.d}` k-owned, since sops-nix symlinks the secret but won't
create user-owned parent directories.

Imported on every darwin host but disabled by default — hosts opt in with
`programs.ssh-private-hosts.enable = true;` (gated because mini/SOC have no
age recipients yet and would fail decryption at activation);
mounted ungated on every NixOS host
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).
A cross-OS twin — parallel implementations in each class dir (see the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md)).

## Citations

- [sops-nix](https://github.com/Mic92/sops-nix) — per-secret
  `owner`/`path`/`sopsFile` options
- `ssh_config(5)` — `Include` (relative to `~/.ssh`), `Match exec`

## Source

- darwin module: [`modules/darwin/ssh-private-hosts.nix`](../../modules/darwin/ssh-private-hosts.nix)
- NixOS module: [`modules/nixos/ssh-private-hosts.nix`](../../modules/nixos/ssh-private-hosts.nix)
- Options under: `programs.ssh-private-hosts` (darwin)
