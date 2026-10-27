---
type: NixOS Module
title: Configuration
description: 'Nebula''s baseline system config — locale/timezone, snowglobe-factory profile toggles, NVIDIA production driver, GRUB dual-boot with a static Windows chainload entry, initrd emergency access, sops-decrypted SSH host keys, and the host''s package/program selections.'
resource: modules/hosts/nebula/configuration.nix
tags: [nixos-module, host-specific]
generated: { by: okflight/0.4.0, at: 2026-07-03T12:00:00-07:00 }
---

Nebula's baseline system configuration — everything host-wide that doesn't
warrant its own file:

- **Locale/keymap/timezone:** `en_US.UTF-8`, `us`, `America/Los_Angeles`.
- **snowglobe-factory toggles:** `qemu` (libvirtd + qemu_kvm + virt-manager) plus
  the `gaming`, `office`, `hacker-mode`, and
  `harden` profiles. Two profiles snowglobe has since deleted live on as
  inlined `environment.systemPackages` lists: `hardware-tools` (dropped
  2026-09; usbutils, smartmontools, nvme-cli, lshw, inxi, vulkan-tools, …)
  and `nix-tools` (dropped 2026-10 in snowglobe-factory b0a0d97b; nurl,
  nix-prefetch-git, deadnix, nixpkgs-hammering, statix, nix-init,
  nix-update, nixpkgs-review, nixfmt — its direnv half is already
  [direnv](direnv.md)). `snowglobe-factory.cups.enable = false` (2026-10-26)
  turns off the office profile's CUPS, its six printer drivers and the Avahi
  daemon it brings. No printers were set up, and hplip kept a vulnerable
  Pillow installed ([decision](../decisions/gajim-pillow-13.md)).
  `programs.corefreq.enable = false` — the out-of-tree
  kernel module doesn't build on kernel 7.1 (CPPC struct field
  `reference_perf` → `reference`); re-enable when upstream catches up.
- **NVIDIA/gaming:** `hardware.nvidia.package` pinned to
  `nvidiaPackages.production` and `programs.gamescope.enableWsi = true` —
  both landed during the HDR campaign (see the manual below).
- **Session:** `services.displayManager.defaultSession = "hyprland-uwsm"`,
  the session provided by [hyprland](hyprland.md)'s `withUWSM`.
- **Boot:** GRUB dual-boot. Windows lives on a separate disk/ESP, which is
  why nebula stays on snowglobe's GRUB rather than systemd-boot (which only
  lists entries on its own ESP). Since 2026-10-24 Windows comes from a static
  `extraEntries` chainload (ESP UUID `B658-8653`, `mkBefore` so it precedes
  snowglobe's extra entries) instead of `useOSProber`. That stops os-prober
  from rescanning and root-mounting the other disk on every rebuild, and
  removes its `lsblk` noise. `gfxmodeEfi = "3440x1440x32"` + `gfxpayloadEfi = "keep"` run the
  menu and early boot at the panel's native mode.
  `boot.initrd.systemd.emergencyAccess = true`: the harden profile locks the
  root account, so when a GC'd generation selected in GRUB dropped stage-1 to
  emergency mode on 2026-06-16 the shell was unusable — passwordless initrd
  rescue is safe here because the root fs is unencrypted ext4 (see
  [disko](disko.md)).
- **SSH host keys:** public halves published to `/etc/ssh` from the repo;
  private halves decrypted by sops (`sops.secrets.ssh_host_*_key`).
- **Substituters:** disables the untrusted `nix-store.earthgman.dev` cache.
- **Packages/programs:** desktop additions (cliphist, fd, gimp, breeze-icons,
  rose-pine-hyprcursor, wowup); firefox/chromium/alacritty/
  batsignal/thunderbird disabled; Gajim built against Pillow 13.0.0 until
  nixpkgs ships it, after which evaluation throws so the override gets
  removed ([decision](../decisions/gajim-pillow-13.md)); 1Password CLI + GUI; nix-ld (cc + zlib); discord plus
  vesktop (its own `programs.vesktop` key since 2026-09; the pnpm whitelist
  is gone — see the
  [vesktop pnpm whitelist decision](../decisions/vesktop-pnpm-whitelist.md));
  hyprpolkitagent runs as a user service (polkit-gnome off).

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/configuration.nix`](../../modules/hosts/nebula/configuration.nix)
- Manual: [`docs/hdr-hyprland-june-2026.md`](../../docs/hdr-hyprland-june-2026.md)
