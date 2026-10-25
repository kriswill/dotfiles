---
type: Decision
title: nrs --plan Runs stc-ng's User Pass Itself
description: 'switch-to-configuration dry-activate exits before switch-to-configuration-ng''s per-user pass, so it never previews user units, the kind that hung nrs on 2026-10-24. nrs --plan therefore runs that pass itself, dry and as the user, through stc-ng''s internal spawn interface, and flags any unit the switch would restart while it is mid-run.'
tags: [nrs, nixos, systemd, switch-to-configuration]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-24T21:20:00-07:00 }
sources:
  - id: stc-ng-source
    resource: https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/sw/switch-to-configuration-ng/src/main.rs
    title: switch-to-configuration-ng source (`do_system_switch`, `do_user_switch`, `record_unit`)
  - id: nrs-pipeline
    resource: ../../docs/nrs-pipeline.html
    title: 'docs/nrs-pipeline.html: the nrs pipeline, design interrogation and proposals'
---

**Where:** [nrs](../modules/nrs.md) (`plan_nixos`, `plan_user_units` and
`plan_hazards` in `pkgs/nrs.sh`). Proposal P10 in the pipeline
report.[^nrs-pipeline] Background:
[Keep Long-Running User Oneshots Out of the Switch's Restart Set](user-oneshots-skip-switch-restart.md).

## Context

P10 asked for a preview of the switch: build, then
`sudo $out/bin/switch-to-configuration dry-activate`. The report assumed
dry-activate also prints the user pass's "would restart the following user
units". It does not. In switch-to-configuration-ng (nixpkgs `3ec6363`),
`do_system_switch` prints the system plan, runs `$out/dry-activate`, and
then calls `std::process::exit(0)`. The per-user loop that spawns
`do_user_switch` comes later, so dry-activate never reaches it.
`do_user_switch` has a complete dry-run branch ("would stop / NOT restart /
reload / restart / start the following user units"), but dry-activate never
calls it.[^stc-ng-source] A preview built on dry-activate alone would be
blind to exactly the unit class that hung `nrs`.

## Decision

`nrs --plan` runs both halves:
1. **System:** `sudo $out/bin/switch-to-configuration dry-activate`, rendered
   like a real switch. It takes switch-to-configuration's lock and runs the
   pre-switch checks, so a running nrs unit is refused first.
2. **User:** the pass itself, the way stc-ng spawns it. That means the new
   build's real binary (`$out/bin/.switch-to-configuration-wrapped`,
   resolved), a cleared environment with `XDG_RUNTIME_DIR`,
   `__NIXOS_SWITCH_TO_CONFIGURATION_PARENT_EXE` set to that same binary (it
   must equal `/proc/self/exe`), `TOPLEVEL`, `OLD_TOPLEVEL`, and
   `NIXOS_ACTION=dry-activate`. It runs as you; no root is needed. With that
   action the pass only reads unit files and the user manager's state, and
   `record_unit` writes no lists. Checked against a variant build that
   changed an active user unit: it printed the stop and start, and left
   `/run/user/1000/nixos/` empty.
3. **Hazards:** every unit on a "would restart" or "would start" line, in
   either scope, whose `ActiveState` is `activating` right now is listed in a
   warning. A start job for a oneshot completes only when the run exits, and
   the switch blocks on it. Stop-only units are left out, because a stop job
   just signals a oneshot. A changed unit is also started again, so it is
   still caught.

## Consequences

- The user half rides on stc-ng's **internal** interface: the env-var
  protocol and the wrapper's file name are not public and can change with
  any nixpkgs bump. If the binary is missing, or the pass exits non-zero,
  nrs warns and carries on with the system half.
- Only the invoking user's units are previewed. A real switch runs the pass
  for every logged-in user, and only root could preview the others.
- The preview runs against the current `/etc`. A real switch's user pass
  runs after `/etc` has switched, but it compares `OLD_TOPLEVEL` and
  `TOPLEVEL` explicitly, so the plan is the same.
- Upstream, dry-activate's missing user preview fits naturally into P9's
  issue against switch-to-configuration-ng.
- On darwin there is no dry-activate. `--plan` warns and acts as `--dry`.

[^stc-ng-source]: switch-to-configuration-ng source (`do_system_switch`, `do_user_switch`, `record_unit`)
[^nrs-pipeline]: docs/nrs-pipeline.html: the nrs pipeline, design interrogation and proposals
