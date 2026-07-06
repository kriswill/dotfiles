---
type: NixOS Module
title: Gtk Dark
description: 'Installs the adw-gtk3 theme so the portal-broadcast gtk-theme=adw-gtk3-dark resolves — dark GTK3 apps without the GTK_THEME env var that breaks libadwaita styling.'
resource: modules/nixos/gtk-dark.nix
tags: [nixos-module]
timestamp: '2026-07-05T12:00:00-07:00'
---

One line of substance: `environment.systemPackages = [ pkgs.adw-gtk3 ]`. On
Hyprland, `xdg-desktop-portal-gtk` broadcasts the appearance settings —
`color-scheme = prefer-dark` darkens GTK4/libadwaita apps by itself, and
`gtk-theme = adw-gtk3-dark` (also named in `home/gtk/`'s `settings.ini`)
themes GTK3 apps, including LibreOffice's gtk3 VCL plugin. This module's job
is to install that theme so the broadcast name actually resolves; nothing
else is needed.

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
