---
type: Decision
title: Open Terminal Links in the Browser of the Machine You Are Looking From
description: 'BROWSER=herdr-open turns a link opened in an hc terminal into a label on that terminal. The herdr-open mod, in whichever Herdr window is in front (and on macOS recently used), opens it there. This is a label rather than an escape sequence because terminal output cannot write labels.'
tags: [herdr, claude-code, browser, security]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-11-18T13:00:00-08:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/herdr/README.md
    title: 'flakes/herdr/README.md, "Links open where you are" (protocol, security, testing, applying)'
  - id: app-terminal
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.16/src/terminal.rs
    title: 'herdr-app 0.1.16 src/terminal.rs (Cmd/Ctrl-click opens a link before mouse reporting; link_mods)'
  - id: app-links
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.16/src/links.rs
    title: 'herdr-app 0.1.16 src/links.rs (Ghostty link pattern; open/xdg-open on the app''s machine)'
  - id: app-labels
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.16/docs/labels.md
    title: 'herdr-app 0.1.16 docs/labels.md (clients share state through terminal labels)'
  - id: app-mod-api
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.16/defaults/herdr.d.ts
    title: 'herdr-app 0.1.16 defaults/herdr.d.ts (terminals() with labels, window().active, focused(), hc(), exec())'
  - id: core-events
    resource: https://github.com/herdrdev/herdr-core/blob/v0.1.21/crates/herdr-core/src/events.rs
    title: 'herdr-core 0.1.21 events.rs (one subscription carries this core''s and other machines'' terminals)'
---

**Where:** [herdr](../packages/herdr.md) (`programs.herdr-core.browser`,
`pkgs/herdr-open.sh`); the mod is `home/herdr-app/.config/herdr-app/mods/herdr-open`,
hosted as an empty float like the
[keys mods](herdr-app-keys-via-hosted-mods.md); enabled on
[nebula](../modules/nebula-herdr.md) and every Mac.

## Context

A plain click on a link in Claude Code on nebula, seen in Herdr on a Mac,
opened the link on nebula. Claude Code's fullscreen TUI turns on mouse
reporting (`?1000h`/`?1006h`), so Herdr passes the click to the program.
Claude Code's `onHyperlinkClick` handler then runs `$BROWSER <url>`, or
`xdg-open`/`open`, on its own machine. That is in Claude Code 2.1.327's
bundled code, the same on Linux and macOS. Herdr itself opens a Cmd-clicked
(Ctrl on Linux) link on the viewing machine before the program gets the
click,[^app-terminal] with `open`/`xdg-open` there,[^app-links] so the
modified click already worked. The aim was plain clicks, and URLs that tools
open on their own, opening on the machine in front of the person, with no
machine names configured.

The host can't tell which client is looking. herdr-core's API has no "who's
attached" and no client verbs. Labels, though, reach every client: a mod
sees them live in `terminals()`, can tell whether its window is in front,
and can run `hc` and programs locally.[^app-mod-api][^app-labels] A label set
on nebula reached k's core as a `labels` event for `nebula/t…` in about
20 ms, and a label written from k came back as fast.[^core-events]

## Decision

- **Host:** `herdr-open`, set as `BROWSER` system-wide. In an hc terminal it
  labels its own terminal `herdr-open.<ms>-<hex>=<url>` and waits up to 2.5 s
  for `<key>.done`. Without an answer it opens locally as before, with
  `BROWSER` unset, because xdg-open falls back to it. Outside hc, for other
  schemes, or with `HERDR_OPEN=off`, it opens locally at once.
- **Client:** the `herdr-open` mod. Only a window in front may claim a
  request. The wait before claiming orders the candidates: 0/100/200 ms if
  the terminal has the keyboard, is on screen in this tab, or is elsewhere.
  On macOS, 10 ms per second of `HIDIdleTime` is added (more than 60 s idle:
  no claim). Linux has no idle time here, so it adds a flat 400 ms. The
  window then writes `<key>.claim=<me>` and reads it back (the last write
  wins), opens the link, and answers `here`. A loopback URL from another
  machine's terminal is answered `host` instead, so it opens where the
  address lives.
- **Not an escape sequence.** An OSC that opens URLs could come from any
  output, such as a `cat` of a hostile file or a remote log. A label can only
  come from a process that talks to a core, which already runs as the owner.
- **Limits:** http(s) only, at most 8 KiB, no whitespace or control
  characters, checked on both sides. The opener runs by argv. At most 6 opens
  every 10 s per window. A toast shows every open whose terminal doesn't have
  the keyboard, and every handback.

## Consequences

- Universal by construction: no machine names configured. Whichever Herdr
  window the person uses opens the link, and it degrades to the old
  behaviour when none answers.[^subflake-readme]
- **Linux has no idle signal.** nebula's window always claims late, so a
  Mac in use wins. But someone at nebula whose Mac was touched within the
  last minute may see the link open on the Mac. An idle daemon writing a
  file (hypridle/swayidle on ext-idle-notify) would close that gap.
- Needs fresh environments: `BROWSER` reaches terminals through the core's
  environment. On NixOS that is the user manager's, set at login. On macOS
  it comes from the shell or launchd. A running core and running programs
  keep their old environment until restarted.
- An OAuth flow with a loopback callback opens on the host (it can only
  complete there), and a toast says so.
- Testable without hands: `herdr-open --where <url>` runs a dry request
  through every window, and `flakes/herdr/tests/herdr-open-mod.test.ts`
  races simulated windows.

[^subflake-readme]: flakes/herdr/README.md, "Links open where you are"
[^app-terminal]: herdr-app 0.1.16 src/terminal.rs, the left-click handler and `link_mods`
[^app-links]: herdr-app 0.1.16 src/links.rs, `open_system`
[^app-mod-api]: herdr-app 0.1.16 defaults/herdr.d.ts, the mod API
[^app-labels]: herdr-app 0.1.16 docs/labels.md, shared state in labels
[^core-events]: herdr-core 0.1.21 events.rs, terminals mirrored from machines
