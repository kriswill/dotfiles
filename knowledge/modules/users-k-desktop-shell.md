---
type: NixOS Module
title: Users K Desktop Shell
description: 'Shell-agnostic system plumbing under whichever integrated Wayland shell nebula runs (Dux Shell today, Noctalia before) — upower/power-profiles-daemon/bluetooth, swaync off, a bare-module-name /etc/pam.d/login for the lock screen, and DDC/CI (i2c + ddcutil) for monitor brightness.'
resource: modules/hosts/nebula/users/k/desktop-shell.nix
tags: [nixos-module, host-specific]
generated: { by: claude-code/opus-5.5, at: 2026-11-03T19:05:00-08:00 }
sources:
  - id: dux-docs-lock-auth
    resource: https://github.com/duxlabs-dev/dux-docs/blob/master/versioned_docs/version-2.0/dms/lock-screen-authentication.mdx
    title: Dux Shell 2.0 docs — lock screen authentication
  - id: noctalia-manual
    resource: ../../docs/noctalia.md
    title: docs/noctalia.md — nebula's Noctalia manual
---

Split out of [users-k-noctalia](users-k-noctalia.md) on 2026-11-03 when
[Dux Shell](users-k-dux-shell.md) replaced Noctalia
([decision](../decisions/dux-shell-replaces-noctalia.md)). Everything here is
needed by *any* integrated shell, so it stays on regardless and switching
shells is a toggle in each shell's own file, not a move of this config.

- **Widget backends:** `services.upower`, `services.power-profiles-daemon`,
  `hardware.bluetooth` — the battery, power-profile and Bluetooth widgets
  both shells draw.
- **swaync off:** the shell owns `org.freedesktop.Notifications`; snowglobe's
  desktop layer (see [hyprland](hyprland.md)) enables swaync, which then
  crash-loops on "Could not acquire notification name".
- **Lock screen vs glibc bumps:** `/etc/pam.d/login` is rewritten so
  linux-pam's own modules have bare names; libpam resolves them against its
  compiled-in dir, so a lock screen started before a glibc-bumping switch
  still loads matching modules and accepts the password.[^noctalia-manual]
  Dux's default lock auth on NixOS copies this `login` stack into
  `~/.local/state/dms/pam/` rather than touching `/etc/pam.d`, so the fix
  carries over to it unchanged.[^dux-docs-lock-auth] ly's re-login stays
  exposed; [nrs](nrs.md)'s PAM glibc warning covers that.
- **DDC/CI brightness:** nebula's DP monitors have no kernel backlight, so
  `hardware.i2c.enable` (i2c-dev, the i2c group, udev rules), `k` in `i2c`,
  and `pkgs.ddcutil`. Whether DDC/CI works over the NVIDIA i2c buses is the
  open question — `ddcutil detect`.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/users/k/desktop-shell.nix`](../../modules/hosts/nebula/users/k/desktop-shell.nix)

[^dux-docs-lock-auth]: Dux Shell 2.0 docs — lock screen authentication
[^noctalia-manual]: docs/noctalia.md — nebula's Noctalia manual
