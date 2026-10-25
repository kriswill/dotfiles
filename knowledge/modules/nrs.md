---
type: Dual Module
title: Nrs
description: 'The rebuild helpers nrs, nrb (nrs --dry) and nrt (nrs --test): nom for the build tree, dix for the diff, and each OS''s own activation, with output streamed and a state report on every exit. They replaced nh on 2026-10-24.'
resource: modules/darwin/nrs.nix
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

Both twins install the same [nrs package](../packages/nrs.md), which is one
bash script that picks its path from `uname -s`, plus `nrb` (`nrs --dry`)
and `nrt` (`nrs --test`) as one-line wrappers. It replaced nh on 2026-10-24.
Until then it ran beside nh's `nrs` as `nrs2`, so the two could be compared
run for run, and nh and its modules are now gone.[^nrs-pipeline]

Both OSes keep the stage order nh used:
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
and colors ([decision](../decisions/stow-ndjson-activity.md)). On the Macs,
Homebrew bundle's one `Using <dep>` line per Brewfile entry collapses the same
way, into a live line and `✔ brew N Brewfile dependencies · N already
installed`. Installs, upgrades and errors still print in full.
sops-install-secrets runs twice per activation (user secrets before `/etc`,
the rest after), and each run printed one long `Imported … key with
fingerprint …` line per key: four near-identical lines per switch. They now
collapse into one, `⚿ sops  keys  rsa → GPG 646fb041…c17120 · ed25519 → age
age1vn8h…chjzrz`. A key already shown is not shown again, so the second run
prints nothing unless its keys differ. The un-prefixed secret-change lines
are marked: `+` for adding and would add, `~` for modifying, `−` for
removing. Its errors, which start with the binary's full store path, are shown
in red.

**NixOS** (`modules/nixos/nrs.nix`):
- **Activation runs as a unit.** `switch-to-configuration test` runs as
  `nrs-switch-to-configuration.service` via
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
  ([decision](../decisions/nrs-boot-menu-check.md)).
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
- **`--plan`** (report P10): build and diff, then preview the switch without
  changing anything. `sudo switch-to-configuration dry-activate` covers the
  system units. dry-activate skips stc-ng's per-user pass, so nrs runs that
  pass itself, dry and as you. Any unit the switch would restart or start
  while it is `activating` is flagged, since the switch would block on it
  ([decision](../decisions/nrs-plan-user-pass.md)).
- **`--status`** (report P17): no build, no root. It prints:
  - the generation trio;
  - the generation count and the oldest generation's age (the rollback
    window);
  - a detached nrs unit that is still running;
  - pending system and user jobs;
  - leftover plan lists and failed units;
  - kernel and PAM drift since boot.

  It exits 1 when any of these needs attention, so scripts can use it. A
  capture mid-debounce shows up as a pending job, and that is real.
- **Previews compare the new build:** `--dry` and `--plan` run the kernel and
  PAM checks against the new build (what a switch and then a reboot would
  change). The other modes check the running system.

**darwin** (`modules/darwin/nrs.nix`):
- **Same order as nh:** set the profile, then run the new generation's own
  `darwin-rebuild activate` under `sudo -H`. That script sets HOME, PATH and
  NIX_REMOTE for root and handles any legacy `activate-user`.
- **Host name:** `scutil --get LocalHostName`, as nh and darwin-rebuild use.
- **No detach.** launchd has no systemd-run equivalent wired in here, so Ctrl-C
  interrupts activation, as it does under nh.
- **Linux-only parts are skipped:** the watchdog, plan lists, unit checks and
  kernel/glibc checks.
- **`--test`** runs the new build's `system.checks` with nothing activated:
  `sudo -H /usr/bin/env -i checkActivation=1 <its bash> $out/activate`. It is
  not `darwin-rebuild check`, which rebuilds as root and then, because
  activate's `#!/usr/bin/env -i` shebang wipes `checkActivation` on macOS,
  performs a full activation. nrs refuses if the script has no check-mode
  exit ([decision](../decisions/nrs-darwin-check-mode.md)).
- **Never under sudo:** nrs refuses to run as root (exit 2). It builds as
  you and asks sudo for the root steps itself. Under sudo it would build as
  root, with nix warning about the kept `$HOME` on macOS, and resolve the
  flake from whatever `$HOME` sudo left. This was found when `sudo nrt`, a
  habit from the old root-requiring nrt, ran the new one on `k`.
- **`nrt` is `nrs --test`** on both OSes, installed by these modules. It
  used to be nh's (`nh os test`) and, on darwin, a bare
  `darwin-rebuild check` that nix-darwin refused without root.

`nrs --dry` builds and diffs without root on both OSes. `nrs --status` works
on both; on darwin it covers the running system, the boot default and the
generations, since the unit, job and kernel checks are Linux-only. On darwin, `--plan` warns
and acts as `--dry`, because nix-darwin has no dry-activate. The modes
(`--dry`, `--test`, `--plan`, `--status`) are mutually exclusive. Arguments
after the mode go to `nix build`, except with `--status`, which refuses
them.

Mounted ungated on every host of both classes
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- darwin module: [`modules/darwin/nrs.nix`](../../modules/darwin/nrs.nix)
- NixOS module: [`modules/nixos/nrs.nix`](../../modules/nixos/nrs.nix)
- Package: [`pkgs/nrs.nix`](../../pkgs/nrs.nix) + [`pkgs/nrs.sh`](../../pkgs/nrs.sh)

[^nrs-pipeline]: docs/nrs-pipeline.html: the nrs pipeline, design interrogation and proposals
[^stc-ng-source]: switch-to-configuration-ng source
