---
type: Nix Package
title: Nrs
description: 'The rebuild helper for NixOS and nix-darwin, one bash script: nom for the build tree, dix for the diff, the platform''s own activation, and a state report on every exit. It replaced nh on 2026-10-24 (it was nrs2 until then).'
resource: pkgs/nrs.nix
tags: [package]
generated: { by: claude-code/opus-5.5, at: 2026-10-24T17:20:00-07:00 }
sources:
  - id: nrs-pipeline
    resource: ../../docs/nrs-pipeline.html
    title: 'docs/nrs-pipeline.html: the nrs manual (its §10 maps F1–F12 and P1–P17)'
---

The tool behind the [nrs](../modules/nrs.md) module twins. `pkgs/nrs.nix`
wraps `pkgs/nrs.sh` with `writeShellApplication`, so shellcheck runs at build
time. It pins coreutils, dix, gawk, gnugrep and nix-output-monitor, and
deliberately leaves the rest to the ambient PATH:
- `nix` and `nix-store` (the system's own);
- `sudo` (the setuid wrapper);
- `systemctl` and `systemd-run` (the running systemd);
- `scutil` on macOS.

One script serves both OSes, picked by `uname -s`. Each OS keeps nh's stage
order:
- **NixOS:** `switch-to-configuration test` runs as a transient
  `systemd-run` unit, then the profile is set, then `switch-to-configuration
  boot`. Those last two are skipped when `grub.cfg` (read under sudo)
  already boots this build and lists no collected generation; `--boot`
  forces them.
- **darwin:** the profile is set, then the new generation's own
  `darwin-rebuild activate` runs.

The host comes from `uname -n` on NixOS and `scutil --get LocalHostName` on
darwin, matching nh and darwin-rebuild. Besides switching it has four modes:
- `--dry`: build and diff;
- `--test`;
- `--plan`: a dry-activate preview that includes the user units it skips;
- `--status`: a no-root, no-build consistency check that exits 1 when
  something needs attention.

The module card has the details. The design and the findings it
addresses are in the pipeline report.[^nrs-pipeline]

## Source

- Package: [`pkgs/nrs.nix`](../../pkgs/nrs.nix), script [`pkgs/nrs.sh`](../../pkgs/nrs.sh)
- Overlay: [`overlays/nrs.nix`](../../overlays/nrs.nix) — exposes `pkgs.nrs`

[^nrs-pipeline]: docs/nrs-pipeline.html: the nrs manual (its §10 maps F1–F12 and P1–P17)
