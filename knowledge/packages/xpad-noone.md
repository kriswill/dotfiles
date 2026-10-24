---
type: Overlay
title: Xpad Noone
description: 'TEMPORARY — nixpkgs now signs every out-of-tree kernel module with kmodigest during `make modules_install`, and the module aggregator (kmod/aggregator.nix) cats a `<module>.ko.cer` for each external module into modules.cer.'
resource: overlays/xpad-noone.nix
tags: [overlay]
generated: { by: okflight/0.5.0, at: 2026-10-24T02:57:56+00:00 }
---

TEMPORARY — nixpkgs now signs every out-of-tree kernel module with kmodigest during `make modules_install`, and the module aggregator (kmod/aggregator.nix) cats a `<module>.ko.cer` for each external module into modules.cer. xpad-noone (pulled in by hardware.xone ← snowglobe's gaming profile) installed its .ko with a plain `install`, so it never got signed, no .cer existed, and linux-<ver>-modules failed with cat: kernel/drivers/xpad-noone/xpad-noone.ko.cer: No such file or directory Backport of NixOS/nixpkgs#576469 (merged to master 2026-10-22 as ffcd595): install through the kernel's modules_install so kmodigest runs. DELETE this overlay (and its modules/overlays.nix line) once our nixos-unstable lock contains that commit.

## Source

- Overlay: [`overlays/xpad-noone.nix`](../../overlays/xpad-noone.nix)
