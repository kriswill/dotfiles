---
type: Decision
title: Drop GTK_THEME for Portal-Broadcast Theming
description: 'Removed the GTK_THEME=Adwaita:dark session variable (it made libadwaita apps discard their stylesheet — cramped padding) in favor of installing adw-gtk3, which the running portal already broadcasts as the GTK3 theme.'
tags: [gtk, theming, nixos]
timestamp: '2026-07-05T12:00:00-07:00'
---

**Status:** active. **Where:** [gtk-dark](../modules/gtk-dark.md).

## Context

Gajim 2.4.6 (GTK4 + libadwaita) rendered its preferences window with no row
padding or boxed-list styling. Root cause: `gtk-dark.nix` set
`GTK_THEME=Adwaita:dark` session-wide, and libadwaita apps respond to
`GTK_THEME` by discarding their own compiled-in stylesheet — where all the
spacing lives. The variable dated from the niri era, when no
`xdg-desktop-portal` ran and forcing GTK's built-in dark variant was the only
reliable dark-mode lever (see [`docs/libreoffice.md`](../../docs/libreoffice.md)).

Under Hyprland the premise no longer held: `xdg-desktop-portal-gtk` runs and
already broadcast `color-scheme = prefer-dark` and
`gtk-theme = adw-gtk3-dark` (verified live via
`busctl … org.freedesktop.portal.Settings ReadOne`). But no adw-gtk3 theme
was installed anywhere — `settings.ini` and dconf both named a theme that
didn't resolve — so dropping the env var alone would have left GTK3 apps
(LibreOffice's gtk3 VCL plugin) light.

## Decision

Replace the session variable with `environment.systemPackages =
[ pkgs.adw-gtk3 ]`. Layered result: GTK4/libadwaita apps go dark from the
portal's `prefer-dark` alone, keeping their own stylesheet (padding intact);
GTK3 apps resolve the portal/settings.ini theme name `adw-gtk3-dark` to the
now-installed theme.

## Consequences

- Libadwaita apps (Gajim, and anything else GTK4) regain upstream spacing
  while staying dark; GTK3 apps get adw-gtk3's libadwaita-look instead of
  stock Adwaita dark.
- Session-variable removal needs a re-login; already-running apps keep the
  old look until relaunched after that.
- If nebula ever moves to a compositor session without a settings portal,
  dark mode silently reverts to light — the fix then is a portal/settings
  daemon, not the `GTK_THEME` hammer.
- The `busctl`-verified `prefer-dark` broadcast turned out to be reading an
  undeclared, incidental dconf value rather than anything this repo set —
  see the follow-up [decision](nautilus-dbus-warnings.md) that made it
  reproducible.

## Citations

- [`modules/nixos/gtk-dark.nix`](../../modules/nixos/gtk-dark.nix), [`docs/libreoffice.md`](../../docs/libreoffice.md)
- [adw-gtk3](https://github.com/lassekongo83/adw-gtk3)
