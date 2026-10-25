---
type: Dual Module
title: Nrs2
description: 'Prototype rebuild helper that does what nh''s os switch and darwin switch do without nh: nom for the build tree, dix for the diff, and each OS''s own activation, with output streamed and a state report on every exit. Installed beside nrs on all hosts for comparison.'
resource: modules/darwin/nrs2.nix
tags: [darwin-module, nixos-module]
generated: { by: claude-code/opus-5.5, at: 2026-10-24T17:20:00-07:00 }
sources:
  - id: nrs-pipeline
    resource: ../../docs/nrs-pipeline.html
    title: 'docs/nrs-pipeline.html: the nrs pipeline, design interrogation and proposals'
  - id: stc-ng-source
    resource: https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/sw/switch-to-configuration-ng/src/main.rs
    title: switch-to-configuration-ng source
---

Both twins install the same [nrs2 package](../packages/nrs2.md), which is one
bash script that picks its path from `uname -s`. It is a plain-bash
replacement for [nh](nh.md)'s `nrs`, kept beside it so the two can be
compared run for run.[^nrs-pipeline]

Both OSes keep nh's stage order:
1. `nom build` of the host's toplevel;
2. a `dix` diff against `/run/current-system`;
3. an essential-file check;
4. activation;
5. a state report with per-stage timings. It runs on every exit, failures
   included.

Activation output is streamed rather than captured, and rendered. The
[dotfiles-stow](dotfiles-stow.md) restow's NDJSON events become a live
spinner and progress line, then a one-line summary, with heals, conflicts
and reloads listed under it. switch-to-configuration's plan lines get glyphs
and colors ([decision](../decisions/stow-ndjson-activity.md)).

**NixOS** (`modules/nixos/nrs2.nix`):
- **Activation runs as a unit.** `switch-to-configuration test` runs as
  `nrs2-switch-to-configuration.service` via
  `systemd-run --wait --verbose --output=cat`, the way nixos-rebuild-ng does
  it. Checked on nebula: Ctrl-C makes `systemd-run` exit 130 while the unit
  runs to completion, so an interrupt detaches instead of killing the switch
  between STOP and START. That is the 2026-10-24 failure mode
  ([decision](../decisions/user-oneshots-skip-switch-restart.md)).
- **Then the default:** after activation it sets the profile and runs
  `switch-to-configuration boot`. It skips both only when GRUB's own menu
  says there is nothing to do. It reads `/boot/grub/grub.cfg` under the sudo
  it already holds (the ESP is root-only) and checks three things: the
  profile is this build, the default entry's `init=` is this build, and
  every `init=` the menu lists still exists. Any GC since the menu was
  written (nightly, manual, `nh clean`), a cut-off run, or a menu rewritten
  by something else therefore triggers a rewrite. An unreadable or
  unexpected file does too, which is the safe direction. `--boot` forces it.
  `--dry` and `--test` are mutually exclusive (a dry run must never
  activate), and `--boot` warns where it does nothing
  ([decision](../decisions/nrs2-boot-menu-check.md)).
- **Watchdog:** after 45 s it prints pending system and user jobs. It never
  probes `switch-to-configuration.lock`: switch-to-configuration takes that
  lock non-blocking, so a probe could make a real switch abort.[^stc-ng-source]
- **Replays:** leftover plan lists are announced before they replay.
- **Report:** it flags a running system that differs from the boot default,
  failed system and user units, and PAM glibc drift. It also says what a
  reboot would change about the kernel: version, toolchain and config, read
  from `/proc` for the running kernel and unpacked from the new bzImage the
  way `extract-ikconfig` does, plus kernel parameters and the extra module
  packages in `kernel-modules`. It fires when any of these differ, not only
  when the kernel binary changes.
- **Exit codes:** exit 100 still sets the profile and boot entry. Exit 4 keeps
  nh's rule that a failed activation never becomes the boot default.

**darwin** (`modules/darwin/nrs2.nix`):
- **Same order as nh:** set the profile, then run the new generation's own
  `darwin-rebuild activate` under `sudo -H`. That script sets HOME, PATH and
  NIX_REMOTE for root and handles any legacy `activate-user`.
- **Host name:** `scutil --get LocalHostName`, as nh and darwin-rebuild use.
- **No detach.** launchd has no systemd-run equivalent wired in here, so Ctrl-C
  interrupts activation, as it does under nh.
- **Linux-only parts are skipped:** the watchdog, plan lists, unit checks and
  kernel/glibc checks.
- **`--test`** runs `sudo darwin-rebuild check`. The existing darwin `nrt` runs
  `darwin-rebuild check` without sudo, which current nix-darwin refuses for
  non-root users.

`nrs2 --dry` builds and diffs without root on both OSes. Arguments after the
mode go to `nix build`.

Mounted ungated on every host of both classes
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- darwin module: [`modules/darwin/nrs2.nix`](../../modules/darwin/nrs2.nix)
- NixOS module: [`modules/nixos/nrs2.nix`](../../modules/nixos/nrs2.nix)
- Package: [`pkgs/nrs2.nix`](../../pkgs/nrs2.nix) + [`pkgs/nrs2.sh`](../../pkgs/nrs2.sh)

[^nrs-pipeline]: docs/nrs-pipeline.html: the nrs pipeline, design interrogation and proposals
[^stc-ng-source]: switch-to-configuration-ng source
