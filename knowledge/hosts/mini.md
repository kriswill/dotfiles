---
type: Host
title: mini
description: 'Headless personal M1 Mac mini with 16GB RAM, running Hermes and Herdr with machine SSH authentication and separate prompt-free Git signing.'
resource: modules/hosts/mini/default.nix
tags: [host]
generated: { by: codex/gpt-6, at: 2026-11-14T17:02:07-08:00 }
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
  recipient (`&mini` in `.sops.yaml`) for that token. Since 2026-11-14
  [k](k.md) and [nebula](nebula.md) sign with the same key, which they load
  from a shared sops file instead of 1Password
  ([decision](../decisions/git-signing-key-in-sops.md)); mini's source is
  unchanged.

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
  normally; generation 29 clears the initial launcher-disable override.
  Generation 28 verified restoration suppression,
  Hermes initialization at +28.413 s and signing at about +30 s after kernel
  boot, with normal launchd scheduling on this host.

Generation 29 adds [credential startup](../modules/credential-startup.md)
timing and age-only SOPS import; signing checks local token publication
without spending network backoff. All are warm-verified, with no new reboot.
The [agent credential review](../../docs/mini-agent-credentials.md) keeps
Hermes's designated vault separate and documents how Core delegation
widens its effective user authority. No broader vault grant was deployed.

Kris additionally set `power.sleep.computer = "never"` on Mini and activated
generation 30. Read-only verification on 2026-11-14 confirmed running and
boot-default generation 30 and `pmset` AC `sleep 0`; display sleep remains
10 minutes. This keeps unattended access available during idle periods and
does not change another host's power policy.

## Source

- Host module: [`modules/hosts/mini/default.nix`](../../modules/hosts/mini/default.nix)
