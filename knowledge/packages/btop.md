---
type: Overlay
title: btop
description: 'Patch overlay on btop, the terminal resource monitor: on Linux, the CPU box colours the core labels of the CPUs sharing the largest L3 (nebula''s 3D V-Cache CCD) in the Cached meter''s colour; darwin keeps the cached build.'
resource: overlays/btop.nix
tags: [overlay, patch, cpu]
generated: { by: claude-code/opus-5.5, at: 2026-10-25T18:41:16-07:00 }
sources:
  - id: btop
    resource: https://github.com/aristocratos/btop
    title: btop (aristocratos/btop)
  - id: sysfs-cpu-cache
    resource: https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-devices-system-cpu
    title: 'Linux sysfs ABI: /sys/devices/system/cpu (cpu*/cache/index*/level, size)'
---

Upstream btop has no notion of cache topology: core labels are always
`C0`…`Cn` in the main foreground colour, and no option or theme key marks
cores apart.[^btop] On nebula's 9900X3D that hides the one split that
matters: `0-5,12-17` share the 96 MB V-Cache L3, `6-11,18-23` share 32 MB,
and [Battle.net on nebula](../modules/nebula-battlenet.md) pins WoW to the
first group.

[`btop-largest-l3.patch`](../../overlays/btop-largest-l3.patch) (two hunks
in `src/btop_draw.cpp`) reads each CPU's level-3
`cache/index*/size` from sysfs[^sysfs-cpu-cache] once, at the first draw,
and draws the labels of the CPUs with the largest L3 in the end colour of
the memory box's `cached` gradient (`#26c5ff` in the Default theme). Every
theme defines that gradient, so the highlight follows the theme; inactive
CPUs stay `inactive_fg`. Label width and layout are unchanged.

Behaviour to know:

- **Uniform L3 → no change.** Offline CPUs (no cache directory) are left out
  of the comparison, so an offline core doesn't make every online one
  "largest".
- **No legend.** btop gives no hint what the colour means; this page is it.
- **Per-core temperatures already split by CCD.** btop maps each CPU's
  `core id` across the k10temp `Tccd*` sensors, so the cyan CPUs show
  `Tccd1` and the rest `Tccd2`.
- **Linux only.** On darwin the overlay returns `prev.btop` untouched (no
  sysfs; patching would only force a source build).
- **Rebase on bumps.** Written against btop 1.4.7 (nixpkgs). If a btop
  update stops it applying, the build fails at `patchPhase`; regenerate the
  diff against the new tag.

Verified on nebula by running the patched build in a 200×50 tmux pane and
reading the escape codes: C0–C5 and C12–C17 in `38;2;38;197;255`, the other
twelve in `38;2;204;204;204`.

## Source

- Overlay: [`overlays/btop.nix`](../../overlays/btop.nix)
- Patch: [`overlays/btop-largest-l3.patch`](../../overlays/btop-largest-l3.patch)
- Host: [nebula](../hosts/nebula.md)

[^btop]: btop (aristocratos/btop), 1.4.7 source: `src/btop_draw.cpp` core loop and `src/btop_config.cpp` options
[^sysfs-cpu-cache]: Linux sysfs ABI: `cpu*/cache/index*/level` and `size` (kB)
