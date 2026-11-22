---
type: Decision
title: Give fastfetch Its Own kitten for Herdr Panes
description: 'The fastfetch wrapper puts a kitten shim first on fastfetch''s PATH: in a herdr-core terminal it asks the terminal for its pixel size and streams the image, because the pty reports no pixels and Herdr refuses the file handoff kitten otherwise picks, and fastfetch''s kitten arguments are fixed.'
tags: [fastfetch, herdr, terminal-graphics]
status: stable
generated: { by: claude-code/fable-5-2, at: 2026-11-21T13:34:57-08:00 }
sources:
  - id: fastfetch-manual
    resource: ../../docs/fastfetch.md
    title: 'docs/fastfetch.md ("Inside Herdr": the probes, the screenshots, the test harness)'
  - id: herdr-app-81
    resource: https://github.com/herdrdev/herdr-app/issues/81
    title: 'herdr-app #81: terminal panes report no pixel size (TIOCGWINSZ 0x0)'
  - id: herdr-core-217
    resource: https://github.com/herdrdev/herdr-core/pull/217
    title: 'herdr-core PR #217: report the cell pixel size in the pty window size'
  - id: herdr-app-302
    resource: https://github.com/herdrdev/herdr-app/issues/302
    title: 'herdr-app #302: Kitty images sent as file paths never draw'
  - id: herdr-app-533
    resource: https://github.com/herdrdev/herdr-app/issues/533
    title: 'herdr-app #533: Kitty graphics query reply arrives after DA1'
  - id: kitten-icat
    resource: https://sw.kovidgoyal.net/kitty/kittens/icat/
    title: 'kitten icat options (--transfer-mode, --use-window-size)'
---

**Where:** the [fastfetch sub-flake](../packages/fastfetch.md)'s
`package.nix` and `kitten-shim.sh`, installed through the
[fastfetch module](../modules/fastfetch.md); it matters in the
[Herdr](../modules/herdr.md) app's panes on every host.

## Context

The `kitty-icat` logo runs [kitten](../packages/kitten.md) as
`kitten icat -n --align=left --place=27x20@0x0 --scale-up <png>`, and
fastfetch has no option to change those arguments. In the Herdr app
(hc 0.1.21, herdr-app 0.1.16) that draws nothing, in two
ways.[^fastfetch-manual]

- **A plain pane shows the ASCII logo.** The pty's `TIOCGWINSZ` pixel fields
  are zero, and kitten reads nothing else, so it quits. The terminal does
  answer `CSI 14 t` with the right size.[^herdr-app-81]
- **`devenv shell` shows an empty box.** devenv's own terminal layer gives
  its inner pty a pixel size, so kitten runs. It then detects a transfer
  method, is told files work, and hands the image over as a path under
  `/dev/shm`. Herdr refuses file media.[^herdr-app-302]

The app itself draws images. With `--use-window-size` and
`--transfer-mode=stream` on the command line, kitten's output rendered in
both places.[^kitten-icat]

Upstream's fix for the first half is open and, by its own review, leaves a
freshly opened pane at 0×0.[^herdr-core-217] hc and the app are upstream's
release builds, repackaged, so there is nothing of ours to patch.

## Decision

- `kitten-shim.nix` builds the shim with `writeShellApplication`, and
  `package.nix` `--prefix`es its bin onto fastfetch's PATH. Only fastfetch
  sees it.
- For `icat` with `HC_TERMINAL_ID` set, the shim queries `CSI 14 t` on
  `/dev/tty` and runs the real kitten with `--transfer-mode=stream` and
  `--use-window-size=<cols>,<rows>,<width>,<height>`. `HC_TERMINAL_ID`
  survives into `devenv shell`.
- Anything else is `exec`ed unchanged: other kitten commands, a call with no
  tty, a terminal that hasn't answered within 0.3 s, and every call outside
  herdr-core. So ghostty, tmux and the herdr TUI get the same arguments as
  before.
- The real kitten is the next one on PATH, not `pkgs.kitten` by store path.
  Each OS keeps whichever kitten it already had, and a missing one still
  fails the way it did.
- Streaming also means kitten sends no detection queries. Herdr answers
  those late and twice, and the extra reply ends up typed into the
  shell.[^herdr-app-533]

Not chosen:

- **A wrapped `kitten` for the whole system.** It would fix a bare
  `kitten icat` in a pane too, but it changes what every caller of kitten
  runs, for a failure only fastfetch's fixed arguments have shown.
- **Setting the pty's pixel size from the shell** (`TIOCSWINSZ` at startup
  and on every resize). It would fix every image tool at once. It also adds
  a terminal query to each shell start, and a resize while another program
  is in front resets the size to zero.
- **Another logo type.** None was tried in Herdr. The manual records native
  `kitty` sending ghostty a payload it rejects, and `kitty-direct` hands the
  terminal a file path, the medium Herdr refuses.[^fastfetch-manual]

## Consequences

- The logo draws in a plain Herdr pane and in `devenv shell`, checked by
  screenshot on nebula with 20 of 20 runs streaming the full image in each.
  The Macs build the same wrapper; it wasn't run there.
- A run costs about 5 ms more (62 ms against 57 ms for kitten alone).
- The wait for the reply is bash's `read -t`. The first version used a
  `stty` timeout, which `read -d` undoes, so a terminal that never answered
  hung fastfetch. No terminal tried by hand was silent; the sub-flake's
  check, which makes one with `script(1)`, found it the same day.
- A terminal no window is showing still answers `CSI 14 t`, so the image is
  sent into it, and may be missing when a viewer attaches later: an empty
  box where the ASCII logo used to be.
- A bare `kitten icat` in a Herdr pane is as broken as before.
- Drop `--use-window-size` when a release fills the pty's pixel fields, and
  `--transfer-mode=stream` when Herdr accepts file media or orders its
  replies. The manual says how to test without the shim.[^fastfetch-manual]

[^fastfetch-manual]: `docs/fastfetch.md`, "Inside Herdr: herdr-core (`hc`) and the Herdr app"
[^herdr-app-81]: herdr-app #81: `ws_xpixel`/`ws_ypixel` are 0 while `CSI 16 t` answers
[^herdr-core-217]: herdr-core PR #217 and its review comment about panes that start at 0×0
[^herdr-app-302]: herdr-app #302: images sent as file paths never draw
[^herdr-app-533]: herdr-app #533: the graphics reply arrives after DA1 and is read as keystrokes
[^kitten-icat]: kitten icat's documented `--transfer-mode` and `--use-window-size` options
