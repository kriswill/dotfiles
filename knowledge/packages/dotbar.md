---
type: Nix Package
title: dotbar
description: Braille-dot progress bar CLI for statuslines and terminals, consumed straight from the tlehman/dotbar flake.
tags: [package]
timestamp: '2026-08-30T20:00:00+00:00'
---

Braille-dot progress bar CLI for statuslines and terminals, consumed straight
from the tlehman/dotbar flake.

Unlike most catalog packages there is no `pkgs/` file: the flake input's own
`packages.<system>.dotbar` output is re-exported by an inline overlay in
`modules/overlays.nix` (the ccglass pattern — the overlay closes over
`inputs`), then installed as a user package on the darwin hosts
(`modules/darwin/user-packages.nix`) and on [nebula](../hosts/nebula.md)
(`modules/hosts/nebula/users/k/default.nix`). The input is pinned to the
head of the upstream nix-flake PR (tlehman/dotbar#1) until flake packaging
merges — bump to a tag (or drop the rev) once it does; the note lives beside
the input in `flake.nix`.

Consumed by the Claude Code statusline
(`home/claude-me/.claude-me/statusline.sh`, dense context bar) and the
[herdr](../modules/herdr.md) tab-bar usage indicator, where
`~/.local/bin/dotbar-usage` renders `dotbar --dense` bars with the ANSI
colors passing through the fork's `ansi = true` command entry — see the
[ANSI tab-bar entries decision](../decisions/herdr-ansi-tab-bar-entries.md)
and the [indicator decision](../decisions/herdr-usage-tab-indicator.md).

## Source

- Input pin + comment: [`flake.nix`](../../flake.nix)
- Overlay: [`modules/overlays.nix`](../../modules/overlays.nix)
- Version at last update: `0.1.0`

## Citations

- Upstream: <https://github.com/tlehman/dotbar>
- Packaging PR pinned to: <https://github.com/tlehman/dotbar/pull/1>
