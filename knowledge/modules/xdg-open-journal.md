---
type: NixOS Module
title: Xdg Open Journal
description: PATH-shadowing xdg-open wrapper that diverts stdout to the systemd journal when running on a tty, hiding the portal reply tuple gdbus prints on every URL open while keeping it inspectable via journalctl.
resource: modules/nixos/xdg-open-journal.nix
tags: [nixos-module]
timestamp: '2026-08-03T05:58:29+00:00'
---

Snowglobe's desktop profile (enabled on [nebula](../hosts/nebula.md)) sets
`xdg.portal.xdgOpenUsePortal = true`, so `xdg-open` routes every open through
`gdbus call … org.freedesktop.portal.OpenURI.OpenURI` — and gdbus prints the
reply, a request-handle tuple like
`(objectpath '/org/freedesktop/portal/desktop/request/…',)`, to stdout. That
noise surfaced in any terminal-driven open (`gh repo view -w`, the
[zsh](zsh.md) `open()` function).

This module installs a `lib.hiPrio pkgs.writeShellScriptBin "xdg-open"` that
shadows the real binary in `$PATH`: when stdout is a tty (`[ -t 1 ]`) it
execs with stdout redirected to `systemd-cat -t xdg-open`, first echoing the
invocation — so `journalctl -t xdg-open` shows both what was opened and the
portal reply. Non-tty callers get a plain exec with stdout untouched, and
stderr always stays on the terminal so real failures remain visible.

Gotchas:

- Wrapping `gdbus` itself was rejected: it would mean overlaying glib (mass
  rebuild), and xdg-open pins gdbus by absolute store path (resholve) anyway.
- Callers that hardcode the xdg-utils store path bypass the wrapper; only
  `$PATH` lookups (gh, shells, scripts) are covered — which is exactly where
  the noise was visible.
- The [zsh](zsh.md) `open()` function deliberately does NOT redirect to
  `/dev/null`: doing so would make stdout a non-tty and skip the journal
  branch entirely.

Mounted ungated on every NixOS host
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/nixos/xdg-open-journal.nix`](../../modules/nixos/xdg-open-journal.nix)

## Citations

- [org.freedesktop.portal.OpenURI](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.OpenURI.html) — the method returns a Request object path; that reply is what gdbus prints
- [xdg.portal.xdgOpenUsePortal](https://mynixos.com/nixpkgs/option/xdg.portal.xdgOpenUsePortal) — sets `NIXOS_XDG_OPEN_USE_PORTAL=1`, which forces xdg-open onto the portal path
