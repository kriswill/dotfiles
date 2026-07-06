---
type: Host
title: nebula
description: nebula — AMD CPU, NVIDIA GPU, UEFI desktop.
resource: modules/hosts/nebula.nix
tags: [host]
timestamp: '2026-07-03T22:30:00-07:00'
---

nebula — AMD CPU, NVIDIA GPU, UEFI desktop. Registers into the `configurations.nixos` registry (realised by `modules/nixos.nix` through snowglobe-lib's `mkNixosHost`). This file carries the host metadata and the shared baseline of its `module`; the host-specific pieces live as their own first-class dendritic files under `nebula/`, each a flake-parts module that merges into `configurations.nixos.nebula.module` (the realizer's `deferredModule` option), so there is no import-tree exclusion and no hand-maintained imports list. Non-`.nix` files (secrets.yaml, *.pub) sit in `nebula/` too — import-tree only picks up `.nix`, so they are ignored by the scan and referenced by path.

Imports every [nixos module](../modules/index.md) (`builtins.attrValues
config.flake.modules.nixos` — the nixos class is currently all-universal, so
nothing is enable-gated; the entries below are host-specific *files* merged in
per the [host-mounted modules pattern](../patterns/host-mounted-modules.md),
not opt-in feature flags). Beyond the imports, the registry entry does two
non-obvious things: it re-applies the full `flake.overlays` set
(`nixpkgs.overlays`, so wowup/hyprland resolve through our overlays) and
explicitly points `sops.defaultSopsFile` at `./nebula/secrets.yaml`, because
`mkNixosHost` only sets it when given a `configDir` we don't pass. Three
further host files under `nebula/users/k/` configure the user:
[users-k](../modules/users-k.md),
[users-k-helium](../modules/users-k-helium.md), and
[users-k-noctalia](../modules/users-k-noctalia.md).

Machine-verified manuals for this host live in `docs/`:
[docs/suspend.md](../../docs/suspend.md) — S3/`deep` suspend, whose single
load-bearing fix is the MSI BIOS setting `Wake Up Event By = OS` (a
non-declarative host fact invisible to the flake and lost on a CMOS reset);
[docs/bootloader-issues-jun-06.md](../../docs/bootloader-issues-jun-06.md) —
the June-2026 unbootable-generations incident and the deliberate return to
GRUB+os-prober for the Windows dual-boot; and
[docs/hdr-hyprland-june-2026.md](../../docs/hdr-hyprland-june-2026.md) — the
verified HDR state on the OLED under Hyprland/NVIDIA, superseding the
historical niri-era
[docs/hdr-niri-june-2026.md](../../docs/hdr-niri-june-2026.md).

## Firmware quirks (MSI MAG X870E Tomahawk WiFi)

Non-declarative BIOS facts, invisible to the flake:

- **`Wake Up Event By = OS`** — required for S3 suspend to hold (see
  [docs/suspend.md](../../docs/suspend.md)); lost on CMOS reset **and on any
  BIOS flash**, so re-set it after either.
- **Warm-reboot DRAM-training hang** (observed 2026-07-03 on BIOS `2.A02`):
  `reboot` stalls at debug code 44 with the yellow DRAM EZ-Debug LED. The
  journal proved userspace shutdown completed cleanly in ~1s through
  systemd-shutdown's final sync — the hang is the firmware re-training DDR5
  (64GB) after the warm reset, a known AM5/AGESA quirk. A cold power cycle
  clears it. Note `reboot` is a warm reset: fans/LEDs staying on is normal;
  the stuck code is the anomaly. If it recurs, update the BIOS past `2.A02`
  (newest at the time: `2.AC3`, 2026-06-26, AGESA 1.3.0.1b Patch A — the
  intervening releases carry EXPO and memory-compatibility fixes) and/or
  enable **Memory Context Restore** in the DRAM settings to skip retraining
  on reboot. systemd also arms the SP5100 hardware watchdog (10-min timeout)
  at shutdown, so a genuinely kernel-hung reboot self-resets within 10
  minutes.

## Host-selective features

- [configuration](../modules/configuration.md) (host-specific file)
- [console-quiet](../modules/console-quiet.md) (host-specific file)
- [disko](../modules/disko.md) (host-specific file)
- [flatpak-repo-user](../modules/flatpak-repo-user.md) (host-specific file)
- [hardware-configuration](../modules/hardware-configuration.md) (host-specific file)
- [hyprland](../modules/hyprland.md) (host-specific file)
- [ly](../modules/ly.md) (host-specific file)
- [sudo-1password](../modules/sudo-1password.md) (host-specific file)
- [windows-mount](../modules/windows-mount.md) (host-specific file)

## Source

- Host module: [`modules/hosts/nebula.nix`](../../modules/hosts/nebula.nix)
