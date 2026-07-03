---
type: Darwin Module
title: Podman Desktop
description: 'Kris'' Podman Desktop, mounted into hosts k + SOC (mini carries no podman stack).'
resource: modules/hosts/podman-desktop.nix
tags: [darwin-module, host-mounted]
timestamp: '2026-07-03T10:23:09-07:00'
---

Kris' Podman Desktop, mounted into hosts k + SOC (mini carries no podman stack). nix-darwin has no programs.podman-desktop, so the config — containers.conf and Podman Desktop's settings.json — lives in the stow tree (home/podman-desktop) and is symlinked into ~ by dotfiles-stow.nix. settings.json is rewritten by the GUI app at runtime; the normalize-podman-settings git filter (see .gitattributes) scrubs the volatile fields on commit. The podman-desktop / podman / vfkit / k9s packages are declared per-host in users.users.k.packages (modules/hosts/*.nix).

Host-mounted feature ([SOC-Kris-Williams](../hosts/SOC-Kris-Williams.md), [k](../hosts/k.md)) — merged
straight into the hosts' configurations per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/podman-desktop.nix`](../../modules/hosts/podman-desktop.nix)
- Stow package: [`home/podman-desktop/`](../../home/podman-desktop/) — see the [stow tree pattern](../patterns/stow-tree.md)
