---
type: Nix Package
title: Gh Config
description: Snapshot/restore gh's config.yml between ~/.config/gh (app-owned) and config/gh/ — gh's atomic-rename saves break stow symlinks, so it left the stow tree for the snapshot pattern.
resource: pkgs/gh-config.nix
tags: [package, config-snapshot]
timestamp: '2026-07-04T04:47:17+00:00'
---

Snapshot/restore CLI (`capture` / `restore` / `diff`) for gh's
`~/.config/gh/config.yml`, following the same model as
[noctalia-config](noctalia-config.md) and [helium-config](helium-config.md):
`gh config set` / `gh alias set` rewrite config.yml via atomic rename, which
replaced the stow symlink with a real file and made stow skip the whole gh
package on every rebuild (bitten 2026-07-03). Plaintext at rest (aliases +
protocol, no PII); `hosts.yml` (auth) is never captured. Unlike the other two,
gh is **cross-platform**: the CLI ships via the [git](../modules/git.md)
module twins on both OSes, and a fresh machine runs `gh-config restore` once
to materialize the live file. Design: `config/README.md`.

Added per the [add-package playbook](../playbooks/add-package.md).

## Source

- Package: [`pkgs/gh-config.nix`](../../pkgs/gh-config.nix)
- Overlay: [`overlays/gh-config.nix`](../../overlays/gh-config.nix) — exposes/replaces `pkgs.gh-config`
