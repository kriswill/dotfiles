---
type: Host
title: mini
description: 'Headless personal M1 Mac mini with 16GB RAM, running Hermes and Herdr with machine SSH authentication and separate prompt-free Git signing.'
resource: modules/hosts/mini/default.nix
tags: [host]
generated: { by: codex/gpt-6, at: 2026-11-13T14:43:17-08:00 }
---

mini - my personal mac mini M1, 16GB RAM.

Imports every [darwin-class module](../modules/index.md); host-selective features
are opted into below per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Host-selective features

- [git-signing-agent](../modules/git-signing-agent.md): enabled; commits sign
  through a root-loaded ssh-agent with no 1Password prompt, for headless
  Claude sessions under herdr core
  ([decision](../decisions/headless-git-signing-agent.md),
  [setup](../playbooks/git-signing-agent-setup.md)). mini is a sops
  recipient (`&mini` in `.sops.yaml`) for that token.

- [SSH client](../modules/mini-ssh-client.md): a separate Ed25519 machine key,
  encrypted for mini with sops, authenticates outgoing SSH without the
  interactive 1Password agent. All managed hosts authorize its public key
  for user `k` ([decision](../decisions/headless-machine-ssh.md)).

- [hermes-agent](../modules/hermes-agent.md): the Hermes Agent gateway and
  CLI as k, with restricted direct sandbox access and explicit delegation
  through the existing Herdr Core socket into k's host authority
  ([mini-hermes-agent](../modules/mini-hermes-agent.md)). The root signing
  token is not a general agent vault credential.

- [Headless login](../modules/headless-login.md): suppress automatic GUI
  session restoration while retaining the desktop. 1Password should launch
  normally; the initial launcher-disable action still needs removal from
  the implementation. Generation 28 verified restoration suppression,
  Hermes initialization at +28.413 s and signing at about +30 s after kernel
  boot, with normal launchd scheduling on this host.

## Source

- Host module: [`modules/hosts/mini/default.nix`](../../modules/hosts/mini/default.nix)
