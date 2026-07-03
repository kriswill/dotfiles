---
type: NixOS Module
title: Configuration
description: Nebula's baseline system config — locale/timezone, snowglobe-lib profile toggles, NVIDIA production driver, GRUB dual-boot via os-prober, initrd emergency access, sops-decrypted SSH host keys, and the host's package/program selections.
resource: modules/hosts/nebula/configuration.nix
tags: [nixos-module, host-specific]
timestamp: '2026-07-03T12:00:00-07:00'
---

Nebula's baseline system configuration — everything host-wide that doesn't
warrant its own file:

- **Locale/keymap/timezone:** `en_US.UTF-8`, `us`, `America/Los_Angeles`.
- **snowglobe-lib toggles:** `qemu` (libvirtd + qemu_kvm + virt-manager) plus
  the `hardware-tools`, `gaming`, `office`, `hacker-mode`, `nix-tools`, and
  `harden` profiles. `programs.corefreq.enable = false` — the out-of-tree
  kernel module doesn't build on kernel 7.1 (CPPC struct field
  `reference_perf` → `reference`); re-enable when upstream catches up.
- **NVIDIA/gaming:** `hardware.nvidia.package` pinned to
  `nvidiaPackages.production` and `programs.gamescope.enableWsi = true` —
  both landed during the HDR campaign (see the manual below).
- **Session:** `services.displayManager.defaultSession = "hyprland-uwsm"`,
  the session provided by [hyprland](hyprland.md)'s `withUWSM`.
- **Boot:** GRUB dual-boot via `boot.loader.grub.useOSProber = true` —
  Windows lives on a separate disk/ESP, which is why nebula stays on
  snowglobe's GRUB rather than systemd-boot (which only lists entries on its
  own ESP). `gfxmodeEfi = "3440x1440x32"` + `gfxpayloadEfi = "keep"` run the
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
  rose-pine-hyprcursor, umu-launcher, wowup); firefox/chromium/alacritty/
  batsignal disabled; 1Password CLI + GUI; nix-ld (cc + zlib); discord
  (vesktop) with `permittedInsecurePackages = ["pnpm-10.29.2"]` per the
  [vesktop pnpm whitelist decision](../decisions/vesktop-pnpm-whitelist.md);
  hyprpolkitagent runs as a user service (polkit-gnome off).

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/configuration.nix`](../../modules/hosts/nebula/configuration.nix)
- Manual: [`docs/hdr-hyprland-june-2026.md`](../../docs/hdr-hyprland-june-2026.md)
