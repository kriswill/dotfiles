---
type: Decision
title: Share One Signing Key Across Hosts, Loaded From sops on k and nebula
description: 'k and nebula sign commits with the key mini already uses, stored as a sops secret and loaded into a root-loaded ssh-agent, so AI harnesses commit without a 1Password approval; mini keeps reading the same key from 1Password.'
tags: [git, secrets, sops, darwin, nixos]
status: stable
generated: { by: claude-code/fable-5.2, at: 2026-11-14T13:40:00-08:00 }
sources:
  - id: sops-nix
    resource: https://github.com/Mic92/sops-nix
    title: sops-nix (age recipients, root-owned secrets under /run/secrets)
  - id: github-signature-verification
    resource: https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification
    title: 'GitHub: about commit signature verification (persistent verification records)'
  - id: ssh-agent-source
    resource: https://github.com/openssh/openssh-portable/blob/master/ssh-agent.c
    title: 'ssh-agent.c handle_socket_read(): only euid 0 or the agent''s own uid may connect'
---

**Where:** [git-signing-agent](../modules/git-signing-agent.md), enabled on
[k](../hosts/k.md) and on [nebula](../hosts/nebula.md) through
[nebula-git-signing-agent](../modules/nebula-git-signing-agent.md).
Procedure: [git-signing-agent-setup](../playbooks/git-signing-agent-setup.md).

## Context

[mini](../hosts/mini.md) has signed commits without a prompt since
2026-11-05 ([headless-git-signing-agent](headless-git-signing-agent.md)).
k and nebula are interactive machines, but many of their commits come from
AI harnesses too: Claude Code and Codex under [herdr](../modules/herdr.md),
[Hermes](../modules/hermes-agent.md). Each of those commits waited on a
1Password approval and failed when nobody gave one. On 2026-11-14 a Claude
session on nebula stopped at `git commit` with `1Password: failed to fill
whole buffer`. Kris asked for mini's arrangement on both hosts, with the
signing key stored in sops and the same key as mini.

## Decision

- **One key for all three hosts:** the key mini already signs with. It is
  already a GitHub signing key and already in `allowed_signers`, so nothing
  new is registered anywhere. Its public half moved from mini's directory
  to `modules/hosts/git-signing.pub`.
- **On k and nebula the private key is itself a sops secret:**
  `git-signing-key` in the shared `modules/hosts/git-signing.yaml`,
  encrypted to those two hosts' age recipients.[^sops-nix] At runtime it is
  root `0400`, and root loads it into an ssh-agent running as `k`. That
  keeps mini's boundary: a session can sign through the socket but can't
  read the key.[^ssh-agent-source]
- **One module, not two.** `services.git-signing-agent` gained the sops key
  source (used whenever `opItem` is unset) and a NixOS twin built on a
  systemd unit.
- **mini is unchanged.** It still reads the key from 1Password with its
  service account, and is not a recipient of the shared file.
- **Host-wide, as on mini.** `/etc/git/host.inc` replaces the signer for
  every commit made on the host.

The mini decision turned down "the private key straight in sops". It was
chosen here because:

- The service account buys little on nebula. Its disk is unencrypted and
  its age key sits on it, so a token at rest is worth as much as the key it
  fetches ([op-service-account-token](op-service-account-token.md) says
  the same of its own token). What the token adds is revocation in one
  place and a read log.
- The agent needs no 1Password and no network to start, and there is no
  token to rotate or to expire unnoticed.
- One file serves both hosts.

Considered and not chosen:

- **mini's service account on all three hosts.** It means `op` in a root
  unit on NixOS and a network round trip at every agent start, for the
  small gain above.
- **A key per host**, as the [machine SSH keys](headless-machine-ssh.md)
  are. Each would need its own GitHub signing key and `allowed_signers`
  line. Kris chose one key.
- **The automation key for agent sessions only**, keeping the personal key
  for commits at the keyboard. git has no condition on who is committing,
  so this means `GIT_CONFIG_*` variables in every harness's environment on
  every host. It also protects nothing: whatever git is configured to do,
  any process running as `k` can reach the agent socket.

## Consequences

- Commits on k and nebula sign without a prompt and without the 1Password
  app, whoever makes them. The personal 1Password key no longer signs
  commits on those hosts. It still signs on the work Mac, and still
  answers sudo on nebula and ssh everywhere.
- A signature no longer says which machine made a commit, or that a person
  approved it. It says the commit came from one of three machines.
- The encrypted key sits in a public repository. Its secrecy rests on the
  age identities of k and nebula: k's derives from its SSH host key, and
  nebula's is root's age keyfile on an unencrypted disk. Whoever obtains
  either can decrypt the key from any clone, at any later time. Treat a
  suspected leak of either as a leak of the signing key, and rotate.
- Rotating or revoking the key takes a commit and a re-encryption, not a
  click in 1Password
  ([playbook](../playbooks/git-signing-agent-setup.md)). Removing it from
  GitHub and `allowed_signers` revokes it for all three hosts at once.
  Commits GitHub has already verified stay verified.[^github-signature-verification]
- k and nebula enable the agent only while `git-signing.yaml` is in the
  tree. Deleting the file turns it off at each host's next
  [nrs](../modules/nrs.md), and commits go back to `op-ssh-sign`.
- mini's daemon restarts once at its next `nrs`: the loader script
  changed, its behaviour with `opItem` did not.
- What was tested before any host activated it is in the
  [module's verification section](../modules/git-signing-agent.md#verification).

[^sops-nix]: sops-nix decrypts with the host's age identity at activation; a secret is root `0400` unless `owner`/`mode` say otherwise.
[^ssh-agent-source]: openssh-portable `ssh-agent.c`: `if ((euid != 0) && (getuid() != euid))` → "uid mismatch".
[^github-signature-verification]: GitHub: "GitHub will not re-verify previously signed commits or retroactively adjust their verification status".
