---
type: Nix Package
title: Pass Xdg
description: pass-xdg — a drop-in `pass` (standard unix password manager) that defaults its store to an XDG-compliant location instead of the upstream default `~/.password-store`.
resource: pkgs/pass-xdg.nix
tags: [package]
timestamp: '2026-07-03T20:00:48+00:00'
---

pass-xdg — a drop-in `pass` (standard unix password manager) that defaults its store to an XDG-compliant location instead of the upstream default `~/.password-store`. pass reads PASSWORD_STORE_DIR from the environment; this wrapper exports it to $XDG_DATA_HOME/password-store (falling back to ~/.local/share/password-store when XDG_DATA_HOME is unset, per the XDG Base Directory spec) and then execs the real pkgs.pass by store path — so it's the same version, no recursion, and an explicitly-set PASSWORD_STORE_DIR in the caller's env still wins.

Added per the [add-package playbook](../playbooks/add-package.md).

## Source

- Package: [`pkgs/pass-xdg.nix`](../../pkgs/pass-xdg.nix)
- Overlay: [`overlays/pass-xdg.nix`](../../overlays/pass-xdg.nix) — exposes/replaces `pkgs.pass-xdg`
