---
type: Decision
title: Per-OS Stow Scoping via Skip Lists
description: home/ stays one flat shared stow tree; each OS's dotfiles-stow module carries an explicit skip list of the other OS's packages, so a new package deploys on both OSes by default.
tags: [stow, dotfiles, architecture]
timestamp: '2026-07-03T14:00:00-07:00'
---

**Status:** active. **Where:**
[modules/darwin/dotfiles-stow.nix](../../modules/darwin/dotfiles-stow.nix),
[modules/nixos/dotfiles-stow.nix](../../modules/nixos/dotfiles-stow.nix),
[stow tree pattern](../patterns/stow-tree.md).

## Context

After the [dual-OS unification](nixos-darwin-unification.md), `home/` serves
both macOS and NixOS, but the stow modules auto-discover **every** directory as
a package. ~7 packages are Linux-only (hyprland, fuzzel, gtk, mimeapps, pupgui,
desktop-entries, diffnav) and ~7 macOS-only (karabiner, glow, kitty, oksh,
podman-desktop, ssh, yazi) — deploying them cross-OS would litter `$HOME` with
dead configs (`Library/` paths on Linux, `.config/hypr` on Macs).

## Decision

Keep `home/` flat and add an explicit `skip = [ … ]` list to each OS's
dotfiles-stow module (a `case`/`continue` in the package loop). The two lists
mirror each other and every entry carries a why-comment.

Rejected alternatives:

- **OS subtrees (`home/{common,darwin,linux}/`)** — cleaner placement
  semantics, but restructures every package path (history churn), complicates
  `dots-adopt`, and makes the common case (cross-platform CLI config) require
  a placement decision. The skip list keeps "add a dir = deployed" and makes
  cross-OS deployment the default, which matches how the tree actually skews.
- **Deploy everything everywhere** — no lists to maintain, permanently messy
  `$HOME` on both sides.

Content-level divergence inside a shared package is handled separately:
ghostty's OS half lives in a generated `os.conf` (`config-file = ?os.conf`
loads last, `?` tolerates absence), git signing branches via
`includeIf gitdir:/Users/ | /home/`.

## Consequences

Moving a package between scopes is a one-line edit + rebuild (stow heals the
links). The lists are the single place to consult for "why isn't X deployed
here". `ssh` stays macOS-only until its 1Password `IdentityAgent` path gets an
OS-conditional split (candidate: ssh `Match`/`Include`).
