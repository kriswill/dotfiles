---
type: Decision
title: Restow Reports as an NDJSON Event Stream
description: 'The dotfiles restow emits one JSON object per line instead of prose, because it runs without a terminal (inside activation, under a systemd unit, darwin-rebuild or boot) and so cannot draw progress itself; nrs, which owns the terminal, renders the events live.'
tags: [stow, activation, nrs]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-10-24T18:30:00-07:00 }
sources:
  - id: nix-darwin-activate-system
    resource: https://github.com/nix-darwin/nix-darwin/blob/master/modules/services/activate-system/default.nix
    title: nix-darwin activate-system launchd daemon (boot-time subset of activation)
---

**Where:** [dotfiles-stow](../modules/dotfiles-stow.md) (emitter, via
`lib/stow-restow-script.nix`), [nrs](../modules/nrs.md) (renderer).

## Context

The restow printed a `stow: restowed <pkg>` line for every package and a
`stow: skipping …` line for every skipped one: about 35 lines per switch,
which read as noise. The goal was nom-style output, with a live progress line
and a compact summary. But the restow never has a terminal:
- **NixOS:** it runs inside switch-to-configuration, which nrs starts as a
  transient systemd unit, so its output goes through journald. It also runs
  at every boot, which puts its output in the journal.
- **macOS:** it runs inside nix-darwin's `activate`, under sudo from
  `darwin-rebuild`. It does **not** run under launchd. The boot-time
  `activate-system` daemon runs only the `checks`, `etc` and `keyboard`
  snippets, not `postActivation`.[^nix-darwin-activate-system]

Cursor control from inside the script would garble the journal and anything
that captures the output.

## Decision

The restow emits NDJSON on stderr, with one event per line:
- `begin`, carrying the package and skip counts, so a renderer can show
  progress;
- `skip`, `heal`, and `ok` with file count and milliseconds;
- `conflict`, carrying stow's own message;
- `end`, with the totals;
- `absent`, when there is no stow tree;
- `failed`, with the exit status, when the restow script itself dies (the
  activation snippet reports it; added when the restow became a single user
  process);
- `reload`, added by the NixOS module for Hyprland.

Strings are escaped in bash, not with jq, so activation and boot pay for no
extra process per event. Streaming through journald was verified line by
line (`systemd-run --wait --verbose --output=cat` piped onward).

nrs pipes each activation stream (the systemd unit on NixOS,
`darwin-rebuild` on macOS) into a renderer. On a terminal, the events drive a
spinner and progress line that is redrawn in place. The `end` event replaces
it with a summary line, for example `✔ stow 27 packages · 412 links · 8
skipped (darwin-only) · 0.84s`. Heals, conflicts (with stow's message) and
reloads are listed under the summary. switch-to-configuration's own plan
lines get glyphs and colors. Without a terminal, the renderer prints the same
summary, with no animation and no color.

## Consequences

- Consumers that do not render events see raw JSON lines: a bare
  `darwin-rebuild` or `nixos-rebuild`, and the boot journal. (nh, which
  only showed output on failure, was removed on 2026-10-24.) The lines are still
  self-describing and greppable, for example
  `journalctl -b | grep '"stow":"conflict"'`.
- The schema is documented in the header of `lib/stow-restow-script.nix`.
  The renderer ignores fields it does not know, and passes through any line
  that is not an event.
- A conflict now carries stow's own explanation in the event. Before, it
  printed only "WARNING conflict/error on <pkg>, skipped".

[^nix-darwin-activate-system]: nix-darwin activate-system launchd daemon (boot-time subset of activation)
