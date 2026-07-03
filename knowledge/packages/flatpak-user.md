---
type: Nix Package
title: Flatpak User
description: A drop-in `flatpak` that defaults the CLI to the per-user installation.
resource: pkgs/flatpak-user.nix
tags: [package]
timestamp: '2026-07-03T20:00:48+00:00'
---

A drop-in `flatpak` that defaults the CLI to the per-user installation. flatpak hardcodes --system as the default and offers no config to change it, so this wrapper (placed earlier on PATH than the real flatpak) injects --user for scope-aware subcommands. It respects an explicit --user/-u/--system/--installation and passes non-scoped subcommands (run/ps/help/--version/build*) through untouched. Calls the real flatpak by store path, so no recursion and the same version.

Added per the [add-package playbook](../playbooks/add-package.md).

## Source

- Package: [`pkgs/flatpak-user.nix`](../../pkgs/flatpak-user.nix)
- Overlay: [`overlays/flatpak-user.nix`](../../overlays/flatpak-user.nix) — exposes/replaces `pkgs.flatpak-user`
