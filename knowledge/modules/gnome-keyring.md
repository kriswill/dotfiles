---
type: NixOS Module
title: Gnome Keyring
description: Enables services.gnome.gnome-keyring, the Secret Service (org.freedesktop.secrets) provider where gh, Helium and Noctalia keep their keys on nebula.
resource: modules/nixos/gnome-keyring.nix
tags: [nixos-module]
generated: { by: claude-code/opus-5.5, at: 2026-10-31T00:00:00+00:00 }
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

It was added for atuin-desktop, whose Hub-connect "Accept" button had no
error handling around its keyring save and hung with no Secret Service
running. That app is gone (archived upstream, removed from nixpkgs; see
`docs/atuin.md`). The keyring stays because other apps moved in: as of
2026-10-31 its login collection holds the gh tokens, Helium's
`Chromium Safe Storage` and `Application key for org.chromium.Chromium`,
Noctalia's encrypted-storage key and a CodeRabbit CLI token. Disabling it
would strand those, and Helium would lose access to its encrypted cookies
and saved passwords. Gajim does not use it: its python-keyring goes to
1Password instead ([decision](../decisions/python-keyring-op-backend.md)).

Mounted ungated on every NixOS host (single host today; see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/nixos/gnome-keyring.nix`](../../modules/nixos/gnome-keyring.nix)
- Conflict removed: [`modules/hosts/nebula/sudo-1password.nix`](../../modules/hosts/nebula/sudo-1password.nix)
- Playbook: [`docs/atuin.md`](../../docs/atuin.md)
