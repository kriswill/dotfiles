---
type: Dual Module
title: Git
description: 'Installs the binaries the stow-managed git config invokes by bare name (git, gh, gh-config, git-lfs, difftastic, …); the config itself — including 1Password SSH signing — is stow, not nix.'
resource: modules/darwin/git.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

Binaries-only module: it installs what the stow-managed git config
(`home/git/`) invokes by bare name. The config itself — including
SSH-format commit signing through the 1Password agent, OS-branched via
`includeIf gitdir:/Users/ | /home/` — lives in the stow tree, not in nix.
gh's `config.yml` is NOT stowed: gh rewrites it via atomic rename, so it's a
`config/gh/` snapshot synced with [gh-config](../packages/gh-config.md)
(shipped by this module on both OSes).
git-lfs and difftastic back the corresponding config sections; ripgrep and jq
(used by aliases/hooks) come from
[user-packages](user-packages.md)/hacker-mode, not here.

## Twin differences

Both install git, gh, git-lfs, and difftastic, but the pager stack is placed
asymmetrically: **nixos** additionally carries `delta` and `diffnav` in this
module (stock delta), while on **darwin**
[`modules/darwin/diffnav.nix`](../../modules/darwin/diffnav.nix) carries only
a kanagawa-wrapped delta for direct CLI use — the diffnav binary itself comes
from each darwin host's user-packages list. There is no nixos
diffnav twin module, and the `home/diffnav` stow package is skip-listed on
darwin — the feature is covered on both OSes, but the package lists are not
literally in sync and the delta theming differs (kanagawa-wrapped on darwin,
stock on nixos). See the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md).

Mounted ungated on every host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- darwin module: [`modules/darwin/git.nix`](../../modules/darwin/git.nix)
- NixOS module: [`modules/nixos/git.nix`](../../modules/nixos/git.nix)
- Stow package: [`home/git/`](../../home/git/) — see the [stow tree pattern](../patterns/stow-tree.md)
