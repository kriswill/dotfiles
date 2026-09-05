---
type: Darwin Module
title: GUI Path
description: 'launchd user-domain PATH injection — macOS gives Dock/Finder-launched apps a bare PATH, so this module publishes the nix profile bins to every GUI app at activation (making gh visible to Claude Code desktop''s CI monitoring, git to editors).'
resource: modules/darwin/gui-path.nix
tags: [darwin-module, launchd, path]
generated: { by: okflight/0.4.0, at: 2026-07-17T02:08:13+00:00 }
sources:
  - id: launchd-user-envvariables-mynixos-option-referen
    resource: https://mynixos.com/nix-darwin/option/launchd.user.envVariables
    title: launchd.user.envVariables — MyNixOS option reference
  - id: claude-code-desktop-docs
    resource: https://code.claude.com/docs/en/desktop.md
    title: Claude Code desktop docs
---

macOS launchd starts GUI apps with `/usr/bin:/bin:/usr/sbin:/sbin` — the
login-shell PATH (assembled from `/etc/zshenv`'s nix hooks) never reaches
them, so tools living only in nix profiles are invisible to anything an app
shells out to. First symptom here: Claude Code desktop's CI monitoring
reporting "gh not installed" while `gh` worked in every terminal.

`launchd.user.envVariables.PATH` applies `launchctl setenv` in the user
domain at activation: all *subsequently launched* GUI apps inherit the nix
directories (`~/.nix-profile/bin`, `/etc/profiles/per-user/<user>/bin`,
`/run/current-system/sw/bin`, `/nix/var/nix/profiles/default/bin`) ahead of
the system defaults. Already-running apps must be relaunched; the username
comes from `system.primaryUser`, not a hardcoded home.

Two-pronged with a stow-tree companion: some apps ignore their inherited
environment and instead parse `~/.zshrc` to recover PATH (Claude Code
desktop does this when Dock-launched). Because the [zsh](zsh.md) module
moves the real rc to `~/.config/zsh/.zshrc` via ZDOTDIR, that probe finds
nothing — so `home/zsh/.zshrc` (deployed by the
[stow tree](../patterns/stow-tree.md) on both OSes) exists purely as a
PATH-export shim: zsh itself never reads it while ZDOTDIR is set, on either
OS, so it is inert for real shells.

Mounted ungated on every darwin host
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/gui-path.nix`](../../modules/darwin/gui-path.nix)
- Probe shim: [`home/zsh/.zshrc`](../../home/zsh/.zshrc)
