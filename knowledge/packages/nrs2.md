---
type: Nix Package
title: Nrs2
description: 'A rebuild helper that replaces nh''s switch path on NixOS and nix-darwin with one bash script: nom for the build tree, dix for the diff, the platform''s own activation, and a state report on every exit. Prototype, installed beside nrs.'
resource: pkgs/nrs2.nix
tags: [package]
generated: { by: claude-code/opus-5.5, at: 2026-10-24T17:20:00-07:00 }
sources:
  - id: nrs-pipeline
    resource: ../../docs/nrs-pipeline.html
    title: 'docs/nrs-pipeline.html: the nrs pipeline, design interrogation and proposals'
---

The tool behind the [nrs2](../modules/nrs2.md) module twins. `pkgs/nrs2.nix`
wraps `pkgs/nrs2.sh` with `writeShellApplication`, so shellcheck runs at build
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
  boot`.
- **darwin:** the profile is set, then the new generation's own
  `darwin-rebuild activate` runs.

The host comes from `uname -n` on NixOS and `scutil --get LocalHostName` on
darwin, matching nh and darwin-rebuild. The design and the findings it
addresses are in the pipeline report.[^nrs-pipeline]

## Source

- Package: [`pkgs/nrs2.nix`](../../pkgs/nrs2.nix), script [`pkgs/nrs2.sh`](../../pkgs/nrs2.sh)
- Overlay: [`overlays/nrs2.nix`](../../overlays/nrs2.nix) — exposes `pkgs.nrs2`

[^nrs-pipeline]: docs/nrs-pipeline.html: the nrs pipeline, design interrogation and proposals
