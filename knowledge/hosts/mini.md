---
type: Host
title: mini
description: 'mini - my personal mac mini M1, 16GB RAM.'
resource: modules/hosts/mini/default.nix
tags: [host]
generated: { by: okflight/0.4.0, at: 2026-07-03T17:53:43+00:00 }
---

mini - my personal mac mini M1, 16GB RAM.

Imports every [darwin-class module](../modules/index.md); host-selective features
are opted into below per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Host-selective features

- [git-signing-agent](../modules/git-signing-agent.md): declared with
  `enable = false` until its 1Password items exist. Once on, commits sign
  through a root-loaded ssh-agent with no 1Password prompt, for headless
  Claude sessions under herdr core
  ([decision](../decisions/headless-git-signing-agent.md),
  [setup](../playbooks/git-signing-agent-setup.md)). mini is a sops
  recipient (`&mini` in `.sops.yaml`) for that token.

- [hermes-agent](../modules/hermes-agent.md): the Hermes Agent gateway and
  CLI as k, inside a Seatbelt sandbox that keeps them out of the rest of
  the home ([mini-hermes-agent](../modules/mini-hermes-agent.md)).

## Source

- Host module: [`modules/hosts/mini/default.nix`](../../modules/hosts/mini/default.nix)
