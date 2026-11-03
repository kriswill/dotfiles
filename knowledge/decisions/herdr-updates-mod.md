---
type: Decision
title: Show herdr Updates in Herdr's Tab Bar from the Nix Check's JSON
description: 'The herdr-updates mod (an icon at the right end of the personal layout''s tab bar, a hover card, and a herdr-changelog pane) draws `herdr-update-check --json` instead of re-deriving update state in JavaScript, because only the Nix side knows the configured packages; the PATH copy became `services.herdr-update-check.finalPackage` so it carries those versions.'
tags: [herdr, herdr-app, mods, nix, updates]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-11-03T12:30:00-08:00 }
sources:
  - id: check-script
    resource: ../../flakes/herdr/pkgs/herdr-update-check.sh
    title: 'flakes/herdr/pkgs/herdr-update-check.sh (the --json shape in its header)'
  - id: updates-mod
    resource: ../../home/herdr-app/.config/herdr-app/mods/herdr-updates/main.js
    title: 'mods/herdr-updates/main.js (icon, hover card, check schedule)'
  - id: changelog-mod
    resource: ../../home/herdr-app/.config/herdr-app/mods/herdr-changelog/main.js
    title: 'mods/herdr-changelog/main.js (CHANGELOG.md slice between two versions)'
  - id: app-agents-md
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.12/defaults/AGENTS.md
    title: 'herdr-app defaults/AGENTS.md (mods, overlays, pane.split with a mod)'
---

**Where:** [Herdr on nebula](../modules/nebula-herdr.md), [herdr](../packages/herdr.md).

## Context

The wish: an update indicator in the top right of Herdr's tab bar, a hover
tip with each from → to and links to changelogs, and a changelog pane on
the right. What counts as an update here is Nix's business: the installed
version is whatever `programs.herdr-{cli,core,app}.package` is, a release is
upstream past that, and after a switch the running server, core or window
can still be on an older store path. `herdr-update-check` already worked all
of that out for its notifications.[^check-script] The copy on PATH didn't,
though: the configured versions reached only the scheduled unit's
environment, and the PATH copy fell back to the flake's own pins.

## Decision

- **The check is the source.** It gained `--json` (installed, latest,
  updates with kind/from/to/url/action), and the module installs
  `finalPackage`, the package wrapped with `environment`, on PATH and in both
  schedulers. The mod execs it and only draws.[^updates-mod] It adds one
  thing the check can't see: `updates()` gives the window's own app and
  core versions, which a Finder-launched macOS bundle doesn't show in `ps`.
- **When it runs:** at start, every 30 minutes, five seconds after
  `/nix/var/nix/profiles` changes (a switch), and from the card's ↻. The
  result sits in `shared("herdr-updates")`, so a restart shows it at once
  and both copies of the mod read the same state.
- **Placement:** the personal layout's `tabs` block became a `topbar` row
  with `tabs` (weight 1) and a 40 px `herdr-updates` block. A floating block
  would have carried a dialog frame and could be dragged.
- **The hover card is the same mod opened as a popup** (`openOverlay`
  with `at` under the icon, from `on_mouse_move` bounds). Shipped mods open
  popups only on click, so hover-to-close is ours: the icon sends
  `herdr-updates.leave`/`stay`, the card closes 300 ms after neither is
  hovered, and the card's `close()` sends `closed` back. A click pins it
  open.
- **The changelog is a mod pane** (`pane.split {direction: "right", mod:
  "herdr-changelog", props}`) split beside the tab's last pane, so it lands
  at the right edge. An earlier one in that tab is closed first. It fetches
  `CHANGELOG.md` at the `to` tag and keeps the `(from, to]`
  sections.[^changelog-mod]
- **Current products link their notes too** (Kris, testing on the mac): the
  card lists every installed product with nothing pending under "Installed
  by nix, current", each with "What's new in ‹installed›". Those open the
  pane without `from`, which shows just that version's section.

## Consequences

- Until the switch that installs the `--json` check, the PATH copy exits 2
  and the card says to rebuild, keeping the last good data.
- The pane's title is the mod folder's name (`herdr-changelog`); mod.json's
  `title` doesn't reach pane headers.
- Testing hover needs real pointer motion: Hyprland cursor warps arrive
  late in GPUI, and `herdr-app shot` returns the last frame drawn, which is
  stale while the window's workspace isn't shown. `nix run nixpkgs#wlrctl --
  pointer move|click` drives the virtual pointer and works.

[^check-script]: `flakes/herdr/pkgs/herdr-update-check.sh`, its header and the `add`/`stale` helpers
[^updates-mod]: `mods/herdr-updates/main.js`, `check`, `pending` and `openChangelog`
[^changelog-mod]: `mods/herdr-changelog/main.js`, `parse` and the `(from, to]` filter
[^app-agents-md]: herdr-app `defaults/AGENTS.md`, "Mods" and "The `herdr` module"
