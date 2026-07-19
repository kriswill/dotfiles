---
type: NixOS Module
title: Gtk Dark
description: 'Installs the adw-gtk3 theme so the portal-broadcast gtk-theme=adw-gtk3-dark resolves, and declares the dconf color-scheme=prefer-dark key the portal reads for GTK4/libadwaita apps — dark theming without the GTK_THEME env var that breaks libadwaita styling.'
resource: modules/nixos/gtk-dark.nix
tags: [nixos-module]
timestamp: '2026-07-05T12:00:00-07:00'
---

Two parts: `environment.systemPackages = [ pkgs.adw-gtk3 ]`, and
`programs.dconf.profiles.user.databases` setting
`org/gnome/desktop/interface.color-scheme = "prefer-dark"`. On Hyprland,
`xdg-desktop-portal-gtk` broadcasts appearance settings by reading dconf —
`color-scheme` darkens GTK4/libadwaita apps, and `gtk-theme = adw-gtk3-dark`
(also named in `home/gtk/`'s `settings.ini`) themes GTK3 apps, including
LibreOffice's gtk3 VCL plugin. This module installs the theme so the broadcast
name resolves, and now also declares the `color-scheme` value itself — see
the [decision record](../decisions/nautilus-dbus-warnings.md) for why that
addition mattered: without it, libadwaita apps fell back to the deprecated
`gtk-application-prefer-dark-theme` key in `settings.ini` instead of the
portal, which is what an undeclared dconf value looks like from the outside.

The module's first incarnation instead forced
`GTK_THEME=Adwaita:dark` session-wide — necessary under niri (no portal ran)
but harmful under Hyprland: libadwaita apps respond to `GTK_THEME` by
discarding their own stylesheet, losing padding/boxed-list styling (see the
[decision record](../decisions/gtk-theme-env-var-removal.md)). Theme changes
still need a re-login for apps launched before the switch.

Mounted ungated on every NixOS host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/nixos/gtk-dark.nix`](../../modules/nixos/gtk-dark.nix)
- Manual: [`docs/libreoffice.md`](../../docs/libreoffice.md)

## Citations

- [adw-gtk3](https://github.com/lassekongo83/adw-gtk3) — the Adwaita-for-GTK3 theme
- [libadwaita styles & appearance](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/main/styles-and-appearance.html) — libadwaita ships and manages its own stylesheet (traditional GTK theming is not supported)
- [`programs.dconf.profiles`](https://mynixos.com/nixpkgs/option/programs.dconf.profiles) — NixOS option reference for declaring default dconf values without home-manager
