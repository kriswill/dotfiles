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

- [agent-remote](../modules/agent-remote.md): a second, key-only sshd on
  port 2122, independent of Remote Login.
- [apple-container](../modules/apple-container.md)
- [ai-usage](../modules/ai-usage.md)
- [claude-account-selector](../modules/claude-account-selector.md)
- [Cognee client trust](../modules/cognee.md) adds [mini](mini.md)'s CA to
  the system PEM bundle and the macOS System Keychain.
- The Cognee Codex pilot uses an agent credential in `~/.cognee/.env` and
  forwards explicit memory writes and recalls to [mini](mini.md). The
  pilot dataset is shared back to the dashboard account for viewing.
- [git-signing-agent](../modules/git-signing-agent.md): commits sign through a
  root-loaded ssh-agent with no 1Password prompt, so AI harnesses can commit
  unattended. The key is the one [mini](mini.md) uses, loaded from the
  shared sops file `modules/hosts/git-signing.yaml` and on only while that
  file is tracked
  ([decision](../decisions/git-signing-key-in-sops.md),
  [setup](../playbooks/git-signing-agent-setup.md)). It signs every commit
  made on k, not only the harnesses'.
- [podman-desktop](../modules/podman-desktop.md)

Codebase-memory is now [disabled fleet-wide](../modules/codebase-memory-mcp.md)
in configuration; the recorded generation-289 comparison predates that removal.
K activated this removal in generation 290; post-boot job, executable and
process checks confirm absence. Other hosts require their next normal NRS
activation. The [startup manual](../../docs/shell-startup-performance.md)
records mixed timing results rather than a claimed whole-boot speedup.

## Apps

The 2026-11-13 boot comparison sets only ai-usage's launchd `ProcessType`
to `Standard` on k. Generation 289's xpcproxy-to-launchd-spawn interval was
0.492 seconds versus generation 288's 62.303 seconds. The unchanged
Background codebase-memory job also improved, from 66.660 to 40.656 seconds,
so this single paired boot supports Standard without isolating all effects
of scheduling and launch validation. Scheduled provider refreshes succeeded
after cached poll deadlines expired. Desktop restoration and 1Password
policy remain unchanged. The [startup manual](../../docs/shell-startup-performance.md)
records the comparison and independently observed remote commands.

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
