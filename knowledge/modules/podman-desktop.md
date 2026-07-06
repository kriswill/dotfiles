---
type: Darwin Module
title: Podman Desktop
description: 'Podman Desktop — the GUI for podman containers and machines; a deliberately thin module (enable toggle + /libexec pathsToLink) with all real config stow-managed, including a git filter that scrubs the GUI''s volatile settings.json rewrites.'
resource: modules/darwin/podman-desktop.nix
tags: [darwin-module, containers, kubernetes]
timestamp: '2026-07-04T00:00:00-07:00'
---

[Podman Desktop](https://podman-desktop.io) is the graphical container and
Kubernetes management app for [podman](../packages/podman.md). Here it
fronts the minikube-on-podman workflow used for work Kubernetes (the
minikube binary itself is not nix-managed; `k9s` accompanies it per host).

Imported on every darwin host but disabled by default — hosts opt in with
`programs.podman-desktop.enable = true;` (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)):
enabled on [k](../hosts/k.md) and
[SOC-Kris-Williams](../hosts/SOC-Kris-Williams.md), deliberately not on
mini.

**The module is deliberately thin.** nix-darwin has no upstream
`programs.podman-desktop`, the packages (podman-desktop, podman, k9s) are
declared per-host, and the config lives in the stow tree — so the module
carries only the enable toggle and one load-bearing fix:
`environment.pathsToLink = [ "/libexec" ]`. podman finds its bundled
vfkit/gvproxy helpers via `$BINDIR/../libexec/podman`, but `os.Executable`
is not symlink-resolved on darwin, so when podman runs via the profile
symlink `$BINDIR` is the profile `bin` — the helpers are only discoverable
if the profile also links `libexec`.

**Config is stowed, with one twist:** `home/podman-desktop/` carries
`containers.conf` (machine `provider = "applehv"`) and Podman Desktop's
`settings.json`. The GUI rewrites `settings.json` at runtime, which would
normally disqualify it from stow (the fate of the
[snapshot-synced configs](../patterns/snapshot-synced-configs.md)) — but it
rewrites in place rather than via atomic rename, so the symlink survives
and a `normalize-podman-settings` git filter (`.gitattributes` + the stowed
git config) scrubs the volatile fields on commit instead.

## Source

- Module: [`modules/darwin/podman-desktop.nix`](../../modules/darwin/podman-desktop.nix)
- Options under: `programs.podman-desktop`
- Stow package: [`home/podman-desktop/`](../../home/podman-desktop/) — see the [stow tree pattern](../patterns/stow-tree.md)

## Citations

- [podman-desktop.io](https://podman-desktop.io) — official site
- [Podman From the Official Binary](../decisions/podman-official-binary.md)
  — why `/libexec` must be linked
