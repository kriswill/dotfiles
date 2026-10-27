---
type: NixOS Module
title: OLED Resume Bump
description: 'DPMS off/on bounce of the DP-3 OLED after every resume from S3, via powerManagement.resumeCommands — works around the PG34WCDM panel staying black while Hyprland reports the output live.'
resource: modules/hosts/nebula/oled-resume-bump.nix
tags: [nixos-module, host-specific, hyprland, display]
generated: { by: okflight/0.4.0, at: 2026-07-16T00:40:55+00:00 }
sources:
  - id: powermanagement-resumecommands-option-reference
    resource: https://search.nixos.org/options?channel=unstable&show=powerManagement.resumeCommands&query=powerManagement.resumeCommands
    title: '`powerManagement.resumeCommands` option reference'
  - id: docs-hyprland-md
    resource: ../../docs/hyprland.md
    title: '`docs/hyprland.md`'
  - id: docs-suspend-md
    resource: ../../docs/suspend.md
    title: '`docs/suspend.md`'
---

The PG34WCDM OLED (DP-3) sometimes doesn't wake after suspend: the panel shows
"no DisplayPort signal" while [Hyprland](hyprland.md) reports the output fully
live (`disabled:false, dpmsStatus:1`) and grim captures it fine. A per-output
DPMS bounce (`hyprctl dispatch 'hl.dsp.dpms({ action = "off", monitor = "DP-3" })'`
then `action = "on"`) wakes
it (verified 2026-07-15), so this module runs that bounce unconditionally on
every resume.

Wiring gotchas, all load-bearing:

- `powerManagement.resumeCommands` runs as **root**; the script re-enters the
  user session with `runuser -u k` and passes the instance signature
  (discovered from `/run/user/1000/hypr`) as `hyprctl -i <sig>`, so hyprctl
  reaches the right IPC socket as the right peer. No `env VAR=…` wrapper:
  git-dated Hyprland store paths contain `=`, which `env` misparses.
- `hyprctl` is taken from `config.programs.hyprland.package`, never
  `pkgs.hyprland` — the flake-provided Hyprland and nixpkgs' are different
  closures (see [Hyprland Unfollows Nixpkgs](../decisions/hyprland-unfollow-cachix.md)).
- The dispatch argument is a **Lua expression** — 0.55 dropped the legacy
  `dpms off DP-3` argument form, and the 2026-10-24 0.56 build dropped the
  positional `hl.dsp.dpms("off", "DP-3")` form for a single table (see the
  manual). The failure only shows in the journal (`sleep-actions-pre-stop`);
  `|| true` keeps it from failing the resume.
- Escalation path when a DPMS bounce isn't enough (true link-training failure,
  e.g. the 240Hz/no-DSC blank): the two-step *mode* bounce in
  [`docs/hyprland.md`](../../docs/hyprland.md) → Learned behaviours.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/oled-resume-bump.nix`](../../modules/hosts/nebula/oled-resume-bump.nix)
