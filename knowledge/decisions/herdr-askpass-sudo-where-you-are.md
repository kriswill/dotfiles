---
type: Decision
title: Ask for sudo's Password in a Dialog of the Herdr Window You Are Looking From
description: 'SUDO_ASKPASS=herdr-askpass starts a labelled prompt terminal for sudo with no terminal (an agent''s shell), and the herdr-askpass mod in every connected Herdr window opens it as a modal dialog. You type the password into a real terminal, so it never travels through a label, an argument or the mod, and a headless Mac like mini can still run sudo for an agent.'
tags: [herdr, claude-code, sudo, security]
status: stable
generated: { by: claude-code/opus-5.5, at: 2026-11-26T13:30:00-08:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/herdr/README.md
    title: 'flakes/herdr/README.md, "sudo asks where you are" (protocol, security, gotchas, testing, applying)'
  - id: sudo-man
    resource: https://www.sudo.ws/docs/man/sudo.man/
    title: 'sudo(8): -A/--askpass and SUDO_ASKPASS ("if no terminal is available")'
  - id: app-mod-api
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.18/defaults/herdr.d.ts
    title: 'herdr-app 0.1.18 defaults/herdr.d.ts (openOverlay with a layout of {terminal} blocks closes itself when its terminal ends)'
  - id: app-agents
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.18/defaults/AGENTS.md
    title: 'herdr-app 0.1.18 defaults/AGENTS.md (mods, overlays, floats, props())'
---

**Where:** [herdr](../packages/herdr.md) (`programs.herdr-core.askpass`,
`pkgs/herdr-askpass.sh`); the mod is
`home/herdr-app/.config/herdr-app/mods/herdr-askpass`, hosted as an empty
float like [herdr-open](herdr-open-links-where-you-are.md) and the
[keys mods](herdr-app-keys-via-hosted-mods.md); enabled on every Mac
(`modules/darwin/herdr.nix`).

## Context

Claude Code's Bash tool runs commands without a terminal, so sudo inside it
fails with "a terminal is required to read the password". On mini, Touch ID
failed too ("UI not available" in sudo's log), and mini is meant to run
headless, seen from Herdr on k over herdr-core's ssh connection. The first
workaround, an `osascript` dialog as the askpass, draws on mini's own screen,
which nobody is looking at. The password prompt has to appear where the
person is, like links do with herdr-open.

herdr-open's trick, a request in a label, would put the answer in a label too,
and a password can't go there: labels are shared with every client and every
process that talks to the core. But a Herdr mod can show a live terminal in a
dialog: `openOverlay` takes a layout of `{terminal}` blocks and closes itself
when that terminal ends.[^app-mod-api] A terminal is already the channel
keystrokes take from any Herdr window to any machine.

## Decision

- **Host:** `herdr-askpass` as `SUDO_ASKPASS`. In an hc terminal it opens a
  FIFO in a 0700 directory and starts a prompt terminal on the same core,
  labelled `herdr-askpass=1` and `herdr-askpass.for=<asker>`, that runs
  itself in `--read` mode. The prompt shows sudo's command line and reads the
  password a key at a time with no echo, then writes `P:<password>` or `C`
  (cancel) to the FIFO. The askpass prints the password for sudo, or exits 1
  on cancel, on a prompt that ends unanswered, or after 180 s.
- **Viewer:** the `herdr-askpass` mod in each Herdr window sees the labelled
  terminal in `terminals()` and opens a modal dialog: the mod again as a
  title bar with Cancel, over the terminal. There's no claim protocol like
  herdr-open's. Every window shows it, and answering in one ends the
  terminal, which closes the others.
- **Trigger:** sudo uses an askpass with no terminal only when `DISPLAY` is
  also set. That held on sudo 1.9.17p2 here, where a probe askpass ran with
  both set and not with `SUDO_ASKPASS` alone; the manual describes only
  `SUDO_ASKPASS`.[^sudo-man] So the module sets `SUDO_ASKPASS` everywhere,
  harmless on its own, and `DISPLAY` goes only in the agent's environment
  (Claude Code's `settings.json` `env`). Plain `sudo` and `nrs`'s `sudo -v`
  then ask through Herdr, with no `-A` and no change to nrs.

Rejected:

- **An askpass reading a password manager or the Keychain** would answer with
  no human in the loop, which is silent root for anything running as k.
  1Password's CLI keeps a Touch ID approval, but that needs someone at a Mac
  with a reader.
- **A native password field in the mod** (gpui-kit has masked inputs). The
  mod runs on the viewing machine and would have to carry the password to
  the asking machine. `exec` takes no stdin, so it would go in an argument or
  through `hc send`, both worse than keystrokes into a terminal there.
- **Writing the prompt into the asking terminal.** Claude Code owns that tty
  and reads from it, so the keystrokes could land in its input box.

## Consequences

The password goes from the keyboard to the prompt's pty along the same path
as any keystroke in a herdr terminal. It never goes into a label, an
argument, a file or the screen, and the prompt terminal is removed (`--rm`)
when it exits. Any process running as k can fake a prompt with the same
labels. That's no worse than such a process wrapping sudo, and the dialog
shows the asking terminal and command.[^subflake-readme]

Three mod pitfalls turned up in testing against k's Herdr, and the README
keeps them. A bar copy that read its role from `init`'s argument watched as
well, and opened a dialog per dialog. `pane.focus` on a terminal in an
overlay fails ("no such pane") and posts a toast. A dialog opened for a
prompt that had just ended never closes, so the bar closes its own dialog
once its terminal isn't live.[^app-agents]

Each viewing machine needs the mod, which means its dotfiles checkout and a
restow. With no window showing the machine, sudo times out after 180 s
instead of failing at once.

[^subflake-readme]: flakes/herdr/README.md, "sudo asks where you are"
[^sudo-man]: sudo(8), -A/--askpass and SUDO_ASKPASS
[^app-mod-api]: herdr-app 0.1.18 defaults/herdr.d.ts, OverlaySpec.layout
[^app-agents]: herdr-app 0.1.18 defaults/AGENTS.md, mods and overlays
