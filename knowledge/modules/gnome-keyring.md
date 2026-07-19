---
type: NixOS Module
title: Gnome Keyring
description: 'Enables services.gnome.gnome-keyring — the Secret Service (org.freedesktop.secrets) provider atuin-desktop needs to save its Hub token.'
resource: modules/nixos/gnome-keyring.nix
tags: [nixos-module]
timestamp: '2026-07-19T05:49:26+00:00'
---

One line: `services.gnome.gnome-keyring.enable = true;`. `ly`'s own NixOS
module (the TUI greeter, see [ly](../hosts/nebula.md)) already sets
`security.pam.services.ly.enableGnomeKeyring = mkDefault
config.services.gnome.gnome-keyring.enable`, so this alone is enough — no
separate PAM wiring needed, login auto-unlocks it.

**Had zero effect on first try**: `modules/hosts/nebula/sudo-1password.nix`
already had `services.gnome.gnome-keyring.enable = lib.mkForce false;`,
added when the 1Password sudo-ssh-agent setup was built to stop
`gcr-ssh-agent` (gnome-keyring's SSH-agent-emulation component) from
claiming `SSH_AUTH_SOCK` ahead of the 1Password agent. `mkForce` always
wins over a plain `= true`, so this module was silently inert until that
line was removed. The line directly above it,
`services.gnome.gcr-ssh-agent.enable = false;`, already isolates the actual
conflict on its own (that file's own comment said as much — "keyring
secrets/pkcs11 stay enabled" — the extra `mkForce false` went further than
its own stated intent) — so removing the `gnome-keyring` force was safe:
`gcr-ssh-agent.enable` stays `false` (verified), `gnome-keyring.enable`
now reads `true` (verified).

Why this exists at all: atuin-desktop's "Accept" button on its Hub-connect
dialog has no error handling around its keyring-save Tauri command — with
no Secret Service running, that call fails and the dialog can never
dismiss (see `docs/atuin.md`).

Mounted ungated on every NixOS host (single host today; see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/nixos/gnome-keyring.nix`](../../modules/nixos/gnome-keyring.nix)
- Conflict removed: [`modules/hosts/nebula/sudo-1password.nix`](../../modules/hosts/nebula/sudo-1password.nix)
- Playbook: [`docs/atuin.md`](../../docs/atuin.md)
