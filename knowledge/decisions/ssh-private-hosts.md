---
type: Decision
title: Sops-Encrypt Private SSH Host Entries
description: Other people's hostnames stay out of the public repo — private ssh Host blocks live in a dedicated sops file deployed to ~/.ssh/config.d/, which the public stow config Include-globs.
tags: [ssh, sops, secrets, privacy]
timestamp: '2026-07-11T12:40:00-07:00'
---

**Status:** active — generalised 2026-07-11 into the
[ssh-private-hosts dual module](../modules/ssh-private-hosts.md): the sops
file moved to the shared `modules/hosts/ssh-hosts.yaml` with
[nebula](../hosts/nebula.md) added as a recipient (re-encrypted fresh from
k's deployed plaintext — public keys only, no host-key decryption needed),
and `home/ssh` left the nixos skip list (per-OS 1Password `IdentityAgent`
via `Match exec uname`). Details below describe the original k-only shape;
mechanics unchanged otherwise. **Where:** [sops](../modules/sops.md),
[ssh-private-hosts module](../modules/ssh-private-hosts.md),
[host k](../hosts/k.md), [stow tree](../patterns/stow-tree.md).

## Context

`~/.ssh/config` is stow-managed (`home/ssh/.ssh/config`), so every `Host`
entry in it is world-readable once the repo is published. The generic
settings (1Password `IdentityAgent`, `ForwardAgent`) are fine to publish, but
host entries for **other people's machines** (hostname, port) are not ours to
expose. The config already ended with `Include /Users/k/.ssh/config.d/*` in
anticipation of exactly this split.

Encrypting the *whole* config instead was rejected: `home/ssh` deploys to all
Macs via [the stow tree](../patterns/stow-tree.md), and
[mini](../hosts/mini.md) / [SOC-Kris-Williams](../hosts/SOC-Kris-Williams.md)
have no age recipients yet (`.sops.yaml` TODO) — they would have lost their
ssh config entirely for no privacy gain.

## Decision

Private `Host` blocks live as one multiline value (`ssh-private-hosts`) in a
**dedicated sops file** `modules/hosts/k/ssh-hosts.yaml` — not in the host's
`secrets.yaml`:

- **Creating a new sops file needs only the public recipients** in
  `.sops.yaml`; adding a key to the existing `secrets.yaml` requires
  decrypting it with the root-only host SSH key (sudo). The dedicated file
  let this land without touching root.
- The file can later gain `mini`/`SOC` as recipients (`sops updatekeys`
  after adding their anchors) independently of `k`'s own host secrets —
  private ssh hosts are wanted on every Mac, host secrets are not.

[Host k](../hosts/k.md) declares the secret with `owner = "k"` (ssh reads it
as the user; the default `root:staff 0400` is unreadable) and
`path = "/Users/k/.ssh/config.d/private-hosts"` — sops-nix symlinks that
path to the decrypted file under `/run/secrets.d/` at activation, and the
public stow config picks it up through its `Include` glob. The previously
loose, untracked `~/.ssh/config.d/k-mini` entry was folded into the secret.

## Consequences

- The public repo shows only the secret's key name; hostnames, ports, and
  users are ciphertext. `git grep` for a private hostname returns nothing.
- Editing entries now needs the host age key and a rebuild to deploy —
  deliberate loss of the stow tree's edit-without-rebuild property:

  ```sh
  SOPS_AGE_KEY=$(sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key) \
    sops modules/hosts/k/ssh-hosts.yaml
  ```

- The loose `~/.ssh/config.d/k-mini` file is redundant after the first
  rebuild (duplicate `Host` blocks are harmless — first-obtained value wins)
  and should be deleted.
- Recipients are `k`-only until the other Macs derive age keys.

## Citations

- [sops-nix](https://github.com/Mic92/sops-nix) — per-secret `owner`/`path`/
  `sopsFile` options ("Set secret permission/owner", "Emit plain file to
  another location" sections)
- Source: [`modules/hosts/ssh-hosts.yaml`](../../modules/hosts/ssh-hosts.yaml),
  [`modules/hosts/k/default.nix`](../../modules/hosts/k/default.nix),
  [`home/ssh/.ssh/config`](../../home/ssh/.ssh/config)
