---
type: Host
title: k
description: 'k - my personal macbook pro M1 max, 64GB RAM.'
resource: modules/hosts/k/default.nix
tags: [host]
generated: { by: claude-code/fable-5.2, at: 2026-11-14T13:40:00-08:00 }
---

k - my personal macbook pro M1 max, 64GB RAM.

Imports every [darwin-class module](../modules/index.md); host-selective features
are opted into below per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Host-selective features

- [apple-container](../modules/apple-container.md)
- [claude-account-selector](../modules/claude-account-selector.md)
- [codebase-memory-mcp](../modules/codebase-memory-mcp.md)
- [git-signing-agent](../modules/git-signing-agent.md): commits sign through a
  root-loaded ssh-agent with no 1Password prompt, so AI harnesses can commit
  unattended. The key is the one [mini](mini.md) uses, loaded from the
  shared sops file `modules/hosts/git-signing.yaml` and on only while that
  file is tracked
  ([decision](../decisions/git-signing-key-in-sops.md),
  [setup](../playbooks/git-signing-agent-setup.md)). It signs every commit
  made on k, not only the harnesses'.
- [podman-desktop](../modules/podman-desktop.md)

## Apps

Installs P4V, P4Admin and P4Merge 2026.3 into `/Applications/Nix Apps`
through `environment.systemPackages`, built with `dontStrip` so Perforce's
signature survives ([decision](../decisions/p4v-nix-apps-dont-strip.md)).

## Secrets

Consumes [sops](../modules/sops.md) secrets: `sops-smoke-test` (end-to-end
decryption proof), plus the shared private ssh hosts file via the gated
[ssh-private-hosts module](../modules/ssh-private-hosts.md)
([decision](../decisions/ssh-private-hosts.md)). A separate
[machine SSH identity](../modules/ssh-client.md) authenticates Herdr to
managed hosts; GitHub and other destinations retain personal authentication.
The commit-signing key is a third secret, `git-signing-key` from the shared
`modules/hosts/git-signing.yaml` (recipients: k and
[nebula](nebula.md)). Unlike the SSH identity it stays root-only: only the
[signing agent](../modules/git-signing-agent.md)'s loader reads it.

## Source

- Host module: [`modules/hosts/k/default.nix`](../../modules/hosts/k/default.nix)
