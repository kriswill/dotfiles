---
type: NixOS Module
title: Cbissue
description: 'Codeberg (Forgejo) issue CLIs — cbissue opens issues, cbissues browses them; the API token is fetched at call time via 1Password `op read`, nothing secret is stored.'
resource: modules/nixos/cbissue.nix
tags: [nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

Installs two CLIs for Codeberg (Forgejo) issue tracking into
`environment.systemPackages`: `cbissue` (open an issue: `cbissue
kriswill/foo "title" "body" -l bug`) and `cbissues` (browse/filter:
`cbissues kriswill/foo --state open`). The derivations live in
[`pkgs/cbissue.nix`](../../pkgs/cbissue.nix) and
[`pkgs/cbissues.nix`](../../pkgs/cbissues.nix), exposed as `pkgs.cbissue` /
`pkgs.cbissues` via the per-package `cbissue` and `cbissues`
[overlays](overlays.md).

No secret is stored in the store or the config: the Codeberg API token is
fetched at call time with 1Password's `op read` (override the token's
1Password reference per call with `$CBISSUE_TOKEN_REF`). This requires an
unlocked `op` on PATH — the same 1Password agent that signs git commits and
backs the codeberg git credential helper.

Mounted ungated on every NixOS host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/nixos/cbissue.nix`](../../modules/nixos/cbissue.nix)
