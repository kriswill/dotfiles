---
type: Darwin Module
title: Gpg
description: GnuPG agent on macOS — the darwin twin of modules/nixos/gpg.nix.
resource: modules/darwin/gpg.nix
tags: [darwin-module]
timestamp: '2026-07-03T12:58:16-07:00'
---

GnuPG agent on macOS — the darwin twin of modules/nixos/gpg.nix. Backs `pass` (modules/darwin/pass.nix) and ad-hoc gpg use; the gnupg *package* was already installed via user-packages.nix ("signature verifier"), this adds the launchd user agent + GPG_TTY wiring.

Mounted ungated on every darwin host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/gpg.nix`](../../modules/darwin/gpg.nix)
