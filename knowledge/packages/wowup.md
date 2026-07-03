---
type: Nix Package
title: Wowup
description: WowUp-CF (the CurseForge fork of WowUp), packaged from the upstream AppImage (github.com/WowUp/WowUp.CF releases).
resource: pkgs/wowup.nix
tags: [package]
timestamp: '2026-07-03T20:00:48+00:00'
---

WowUp-CF (the CurseForge fork of WowUp), packaged from the upstream AppImage (github.com/WowUp/WowUp.CF releases). WowUp has no CLI flag or env var for the WoW install path — it only stores game locations in ~/.config/WowUpCf/, set through the GUI. So this wrapper can't *set* the path; instead, when `wowPath` is given it surfaces that WoW install at a clean, stable location (~/Games/World of Warcraft) and exports WOWUP_WOW_PATH, so you point WowUp at the tidy path once (Options -> "Add WoW") instead of digging into the Proton prefix. `--no-sandbox` is required for the bundled Electron/Chromium to launch on NixOS. Bump version/hash together; get the hash with: nix store prefetch-file --hash-type sha256 \ <https://github.com/WowUp/WowUp.CF/releases/download/v<version>>/WowUp-CF-<version>.AppImage.

Added per the [add-package playbook](../playbooks/add-package.md).

## Source

- Package: [`pkgs/wowup.nix`](../../pkgs/wowup.nix)
- Version at last scaffold: `2.22.0`
- Overlay: [`overlays/wowup.nix`](../../overlays/wowup.nix) — exposes/replaces `pkgs.wowup`
