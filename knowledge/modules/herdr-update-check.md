---
type: NixOS Module
title: Herdr Update Check
description: 'Daily nebula user timer that notifies when upstream herdr (herdrdev/herdr) publishes a stable release newer than the base of our vX.Y.Z-custom fork tag, the cue to rebase the fork.'
resource: modules/hosts/nebula/herdr-update-check.nix
tags: [nixos-module, host-specific]
generated: { by: claude-code/opus-5.5, at: 2026-10-24T16:30:00-07:00 }
sources:
  - id: gh-latest-release
    resource: https://docs.github.com/en/rest/releases/releases#get-the-latest-release
    title: GitHub REST API — Get the latest release
---

A daily systemd user timer on [nebula](../hosts/nebula.md). It compares
`pkgs.herdr.version`, the X.Y.Z that our [herdr](herdr.md) fork package
builds as (the `vX.Y.Z-custom` input in `flake.nix`), against `tag_name` from
the GitHub API's `releases/latest` for herdrdev/herdr. That endpoint returns
the newest non-prerelease, non-draft release, so upstream's `preview-*`
prereleases never fire it.[^gh-latest-release] A strictly newer release pops a
dismissable critical notification ("rebase `custom` onto vA.B.C, tag
vA.B.C-custom, repoint the input"); clicking the action opens that release's
page. Our version is read from the package rather than hard-coded and reaches
the script as `HERDR_FORK_VERSION` in the unit's environment, so
bumping the flake input re-baselines the check. The old 0.8.2 constant went
stale and nagged daily. nixpkgs' herdr is deliberately ignored.

The notification blocks `notify-send -A` for up to 12h, so the unit is
`Type=exec` with `restartIfChanged = false`. As a oneshot it hung `nrs`; see
[user oneshots skip switch restart](../decisions/user-oneshots-skip-switch-restart.md).
The rebase procedure it prompts is in
[herdr-ansi-tab-bar-entries](../decisions/herdr-ansi-tab-bar-entries.md) and
[herdr-token-bar-patch](../decisions/herdr-token-bar-patch.md).

The check is plain bash in `herdr-update-check.sh`, wrapped by
`writeShellApplication` (shellcheck at build time). It has no Nix
interpolation, so it runs standalone:
`HERDR_FORK_VERSION=0.9.4 bash modules/hosts/nebula/herdr-update-check.sh`.

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/herdr-update-check.nix`](../../modules/hosts/nebula/herdr-update-check.nix)
- Script: [`modules/hosts/nebula/herdr-update-check.sh`](../../modules/hosts/nebula/herdr-update-check.sh)

[^gh-latest-release]: GitHub REST API — Get the latest release
