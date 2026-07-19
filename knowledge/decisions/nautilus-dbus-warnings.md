---
type: Decision
title: Declare dconf color-scheme and enable localsearch for Nautilus
description: 'Fixed two of Nautilus''s three startup warnings under Hyprland by declaring the dconf color-scheme key the portal broadcasts (instead of relying on the deprecated gtk-application-prefer-dark-theme fallback) and by enabling services.gnome.localsearch so its D-Bus service is activatable; the third (Mutter ServiceChannel) has no fix outside GNOME Shell.'
tags: [gtk, nautilus, dconf, hyprland, nixos]
timestamp: '2026-07-18T19:39:32-07:00'
---

**Status:** active. **Where:** [gtk-dark](../modules/gtk-dark.md),
[localsearch](../modules/localsearch.md).

## Context

`nautilus .` on nebula printed three startup warnings:

1. `Adwaita-WARNING: Using GtkSettings:gtk-application-prefer-dark-theme with
   libadwaita is unsupported. Please use AdwStyleManager:color-scheme
   instead.`
2. `Unable to create connection for session-wide Tracker indexer: The name
   is not activatable.`
3. `Failed to initialize display server connection: … proxy is for the
   well-known name org.gnome.Mutter.ServiceChannel without an owner.`

(1) traced back to [gtk-dark](../modules/gtk-dark.md) and
[home/gtk](../modules/dotfiles-stow.md)'s `settings.ini`. The
[prior decision](gtk-theme-env-var-removal.md) that dropped `GTK_THEME`
asserted `xdg-desktop-portal-gtk` already broadcast
`color-scheme = prefer-dark` on its own — verified live via `busctl`, but
nothing in the repo ever *declared* that dconf value; the busctl read was
against whatever was already sitting in nebula's live (unmanaged) dconf
database. Nautilus is GTK4/libadwaita, and libadwaita's `AdwStyleManager`
only reads `color-scheme` from the portal — but it still honors the legacy
`gtk-application-prefer-dark-theme` key from `settings.ini` as a compat
fallback, with a deprecation warning. That fallback is exactly what was
firing: the moment dconf doesn't carry a declared `color-scheme`, the whole
scheme depends on whatever got poked into the live database out-of-band.

(2) is unrelated: Nautilus's live-search feature tries to D-Bus-activate
`org.freedesktop.Tracker3.Miner.Files`, but nothing installed
`localsearch` (nixpkgs's 2025 rename of `tracker-miners`; see
[localsearch](../modules/localsearch.md)) or registered its D-Bus service
file, so there was no activatable name to invoke.

(3) is Nautilus probing GNOME Shell/Mutter's private
`org.gnome.Mutter.ServiceChannel` for compositor integration (screen
cast/remote desktop plumbing) that simply doesn't exist under Hyprland — no
NixOS config closes that gap short of running Mutter itself.

## Decision

- [gtk-dark](../modules/gtk-dark.md) now declares
  `programs.dconf.profiles.user.databases` with
  `org/gnome/desktop/interface.color-scheme = "prefer-dark"`, making the
  portal's broadcast value reproducible instead of incidental.
- The now-redundant `gtk-application-prefer-dark-theme=1` line was removed
  from `home/gtk/.config/gtk-4.0/settings.ini` (GTK4-only — GTK3 has no
  portal fallback for `color-scheme`, so `gtk-3.0/settings.ini` keeps it, per
  the [gtk-dark](../modules/gtk-dark.md) comment about LibreOffice's gtk3 VCL
  plugin).
- New [localsearch](../modules/localsearch.md) module sets
  `services.gnome.localsearch.enable = true`.
- (3) was left alone — no NixOS config can satisfy a GNOME Shell-only D-Bus
  interface on a non-Mutter compositor.

## Consequences

- Dark theming for libadwaita apps no longer depends on whatever was
  manually poked into nebula's dconf database at some point in the past;
  a fresh nebula install now gets `prefer-dark` from the module alone.
- Nautilus gains live filesystem search indexing as a side effect of
  fixing the warning (localsearch actually runs now).
- Verified live: rebuilt (`nrs`), `nautilus .` re-run — warnings 1 and 2
  gone, warning 3 unchanged as expected.

## Citations

- [`modules/nixos/gtk-dark.nix`](../../modules/nixos/gtk-dark.nix), [`modules/nixos/localsearch.nix`](../../modules/nixos/localsearch.nix)
- [`programs.dconf.profiles`](https://mynixos.com/nixpkgs/option/programs.dconf.profiles)
- [nixos/modules/services/desktops/gnome/localsearch.nix](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/desktops/gnome/localsearch.nix)
