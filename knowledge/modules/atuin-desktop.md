---
type: NixOS Module
title: Atuin Desktop
description: 'Installs pkgs.atuin-desktop, the Tauri GUI runbook editor companion to the atuin CLI (see zsh.md).'
resource: modules/nixos/atuin-desktop.nix
tags: [nixos-module]
timestamp: '2026-07-19T05:08:50+00:00'
---

One line: `environment.systemPackages = [ pkgs.atuin-desktop ];`. The
derivation ships its own `.desktop` entry and icons, so no
`desktop-entries` stow work or nixos module logic beyond the package list
is needed — app launchers (Fuzzel) pick it up automatically. Distinct from
the [atuin](zsh.md) CLI package (same upstream project, separate app);
keeps its own state under `~/.config/sh.atuin.app/` — see `docs/atuin.md`.

Has a known, always-reproduces-on-Nix upstream bug: first-launch's welcome
workspace setup fails with "Permission denied (os error 13)". Root cause
(verified against upstream source, `docs/atuin.md` has the full trace): the
app copies its bundled example workspace out of the (permanently read-only)
Nix store via `fs::copy`, which preserves the source's `444` permission
bit, then immediately tries to rewrite the copy — EACCES every time. No
nix-level fix is possible (Nix makes all store paths read-only
unconditionally); it's an upstream code fix. Workaround: use "Create new
workspace" instead of the auto-offered welcome one.

Mounted ungated on the single NixOS host today (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).
Retrofit a `programs.atuin-desktop.enable` gate if a second, non-desktop
NixOS host ever appears (per [cross-OS module twins](../patterns/cross-os-module-twins.md)
conventions for host-selective features).

## Source

- Module: [`modules/nixos/atuin-desktop.nix`](../../modules/nixos/atuin-desktop.nix)
- Playbook: [`docs/atuin.md`](../../docs/atuin.md)
