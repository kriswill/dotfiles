---
type: NixOS Module
title: Flatpak Repo User
description: Masks snowglobe's system flatpak-repo service and replaces it with a per-user oneshot that registers Flathub in ~/.local/share/flatpak at login, gated on a DNS ExecCondition so offline logins skip cleanly.
resource: modules/hosts/nebula/flatpak-repo-user.nix
tags: [nixos-module, host-specific]
timestamp: '2026-07-03T12:00:00-07:00'
---

Masks snowglobe's *system* `flatpak-repo` service
(`systemd.services.flatpak-repo.enable = false`) and replaces it with a
per-user oneshot (`systemd.user.services.flatpak-repo`, `RemainAfterExit`)
that registers the Flathub remote in `~/.local/share/flatpak` at login via
`flatpak remote-add --user --if-not-exists`.

`remote-add` touches the network even with `--if-not-exists`, and a user
service has no `network-online.target` to lean on, so an `ExecCondition`
shell script polls `getent ahosts dl.flathub.org` for ~30s and exits 1 when
unresolvable — systemd then *skips* (not fails) the unit offline and retries
at the next login.

Pairs with `pkgs.flatpak-user` (the flatpak CLI defaulted to `--user`)
installed in [users-k](users-k.md).

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/flatpak-repo-user.nix`](../../modules/hosts/nebula/flatpak-repo-user.nix)
