---
type: Dual Module
title: Gpg
description: 'gpg-agent on both OSes with enableSSHSupport deliberately false — 1Password owns SSH_AUTH_SOCK; gpg only backs `pass` and ad-hoc gpg use.'
resource: modules/darwin/gpg.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

Enables `programs.gnupg.agent.enable = true` with
`enableSSHSupport = lib.mkDefault false` on both OSes. The `false` is the
point: gpg-agent must not claim `SSH_AUTH_SOCK`, because both SSH auth and
git commit signing go through the 1Password agent — gpg-agent only backs
[pass](pass.md) and ad-hoc gpg use ("signature verifier"). `mkDefault` leaves
the door open for a host to override, but none does. The June-2026 CVE audit
(manual below) reviewed this stack (GnuPG 2.4.9) and concluded no
remediation was needed.

## Twin differences

Options are essentially identical. Darwin's gnupg *package* comes from
[user-packages](user-packages.md); the module adds the launchd user agent +
`GPG_TTY` wiring. The nixos side was hoisted out of nebula's
`configuration.nix` to be class-wide. No drift — see the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md).

Mounted ungated on every host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- darwin module: [`modules/darwin/gpg.nix`](../../modules/darwin/gpg.nix)
- NixOS module: [`modules/nixos/gpg.nix`](../../modules/nixos/gpg.nix)
- Manual: [`docs/security-audit-cve-jun-2026.md`](../../docs/security-audit-cve-jun-2026.md)
