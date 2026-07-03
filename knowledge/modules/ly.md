---
type: NixOS Module
title: Ly
description: Disables ly's F5/F6 brightness actions (and their hint-bar entries) by setting brightness_down_key/brightness_up_key to the literal "null" — ly itself is enabled by snowglobe's shared desktop layer.
resource: modules/hosts/nebula/ly.nix
tags: [nixos-module, host-specific]
timestamp: '2026-07-03T12:00:00-07:00'
---

Tweaks the ly TUI login greeter. ly itself is enabled elsewhere — by
snowglobe-lib's shared desktop module (`services.displayManager.ly.enable`),
switched on via `snowglobe-lib.desktop.enable` in [hyprland](hyprland.md);
its config.ini is built from `defaultConfig //
services.displayManager.ly.settings`, so anything set here overrides ly's
defaults.

This file sets `brightness_down_key`/`brightness_up_key` to the literal
string `"null"`, which (per ly's own config.ini) disables the F5/F6
brightness actions and removes their entries from the function-key hint bar.
That is narrower than `hide_key_hints`, which would also hide the
shutdown/reboot/toggle-password hints. nebula is a desktop machine with no
panel backlight, so the brightness keys could never work anyway.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/ly.nix`](../../modules/hosts/nebula/ly.nix)
