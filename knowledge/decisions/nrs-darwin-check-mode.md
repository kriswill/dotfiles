---
type: Decision
title: nrs --test Runs nix-darwin's Check Mode Directly
description: 'On macOS, `darwin-rebuild check` performs a full activation: activate''s `#!/usr/bin/env -i` shebang wipes the `checkActivation=1` it exports. nrs --test (and nrt, which is now nrs --test) runs the new build''s activate through its own bash under env -i with only checkActivation=1, and refuses if the script has no check-mode exit.'
tags: [nrs, nix-darwin, macos, activation]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-24T22:55:00-07:00 }
sources:
  - id: nix-darwin-activation-scripts
    resource: https://github.com/nix-darwin/nix-darwin/blob/master/modules/system/activation-scripts.nix
    title: nix-darwin activation-scripts.nix (the activate shebang)
  - id: nix-darwin-checks
    resource: https://github.com/nix-darwin/nix-darwin/blob/master/modules/system/checks.nix
    title: nix-darwin checks.nix (the checkActivation exit)
  - id: nix-darwin-rebuild
    resource: https://github.com/nix-darwin/nix-darwin/blob/master/pkgs/nix-tools/darwin-rebuild.sh
    title: nix-darwin darwin-rebuild.sh (check)
---

**Where:** [nrs](../modules/nrs.md) (`activate_darwin` in `pkgs/nrs.sh`),
and `nrt` in `modules/{darwin,nixos}/nrs.nix`. It replaces the old `nrt`
from the nh module, which was removed on 2026-10-24.

## Context

darwin's `nrt` was `darwin-rebuild check --flake ~/src/dotfiles`, without
sudo. Current nix-darwin refuses that: "system activation must now be run
as root". `nrs --test`, then named `nrs2 --test`, ran it under sudo. Reading nix-darwin `bb0b90d`
(the pinned version) showed what `check` does:
1. It rebuilds the system from the flake, as root.
2. It runs `export checkActivation=1; "$systemConfig/activate"`.[^nix-darwin-rebuild]
3. activate's `system.checks` snippet exits with `ok` only when
   `${checkActivation:-0}` is 1.[^nix-darwin-checks]

But activate's first line is `#!/usr/bin/env -i ${stdenv.shell}`.[^nix-darwin-activation-scripts]
macOS splits shebang arguments, so `env -i` really runs and clears the
environment, `checkActivation` included. Checked on the Mac (`k`): a probe
built from the real activate's own first line printed
`checkActivation=[unset]` when run the way darwin-rebuild runs it. The
check-mode exit is skipped, so **`sudo darwin-rebuild check` performs a full
activation**: `/etc`, launchd, defaults, Homebrew and the restow. Only the
profile isn't set. On Linux the kernel passes `-i <shell>` as one argument,
which is presumably why this went unnoticed. A web search found no report of
it.

## Decision

- **`nrs --test` on darwin calls check mode directly**, on the build it
  already made as the user, with no second evaluation as root:
  `sudo -H /usr/bin/env -i checkActivation=1 <bash> $out/activate`. The
  bash is the last word of activate's shebang; it must be the store bash,
  because the script needs bash 4 and macOS `/bin/bash` is 3.2. Running the
  script through bash means the shebang is never used. `env -i` keeps the
  clean environment the shebang intends, with only `checkActivation` added.
  The same probe printed `checkActivation=[1]`. This runs the
  `preActivation` snippets and `system.checks`, then exits `ok`, which is
  what nix-darwin meant `check` to do.
- **Guard:** if activate lacks the `checkActivation:-0}" -eq 1` exit, or its
  shebang's bash isn't executable, nrs refuses. A future nix-darwin can't
  turn `--test` into a silent activation.
- **`nrt` is `nrs --test` on both OSes.** It lives in the nrs modules as
  `exec nrs --test "$@"`. On NixOS that is still "activate without the
  profile or a boot entry", now with nrs's unit, rendering and report.

## Consequences

- Over SSH, `system.checks` fails at nix-darwin's "Allow full disk access
  for remote users" check, so `nrt` on a Mac belongs in a local terminal.
- The upstream bug stands for anyone running `darwin-rebuild check` on
  macOS. It's worth reporting to nix-darwin; the fix there is to pass
  `checkActivation` in a way `env -i` keeps (an argument, or exec through
  the shell).

[^nix-darwin-activation-scripts]: nix-darwin activation-scripts.nix (the activate shebang)
[^nix-darwin-checks]: nix-darwin checks.nix (the checkActivation exit)
[^nix-darwin-rebuild]: nix-darwin darwin-rebuild.sh (check)
