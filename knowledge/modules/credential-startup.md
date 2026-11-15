---
type: Darwin Module
title: Credential Startup
description: 'Mini keeps SOPS secrets on the protected RAM filesystem, imports only its age identity, and timestamps boot installation independently of activation.'
resource: modules/hosts/mini/credential-startup.nix
tags: [darwin-module, host-specific]
generated: { by: codex/gpt-6, at: 2026-11-13T15:07:54-08:00 }
sources:
  - id: startup-manual
    resource: ../../docs/shell-startup-performance.md
    title: Cold-boot evidence and generation-29 warm validation
---

Mini's two deployed secret files have age recipients only. This host override
disables the unused RSA-to-GPG import; it does not change
[GnuPG](gpg.md), pass, the SSH server's RSA key, or other hosts' key sources.
If adding a PGP recipient in future, revisit this explicit age-only choice.

The native-shell launchd wrapper preserves upstream's SOPS install command
and waits for the store executable before running it. It logs store-wait,
install start, exit status and whole-second elapsed time to
`/var/log/sops-boot.log`, without tracing secrets or environment values.
It retains the original once-at-load behavior and error propagation.

Pinned sops-nix creates a 64 MiB HFS RAM disk before decrypting secrets.
Generation 28's `hdiutil` startup was observed at 22:19:30.787709 UTC,
with exit-handler completion at 22:19:40.723596 and secrets published at
22:19:40.907725. This places substantial delay in RAM-disk setup, not a
dependency on [boot activation](boot-activation.md). Keep the mount and
permissions; removing the unused GPG conversion has no measured cold-boot
speedup yet. See the [startup manual](../../docs/shell-startup-performance.md).

Generation 29 activated successfully: the SOPS boot job logged exit 0,
elapsed 0 s, reusing the already-mounted RAM disk. Root signing-token and
user SSH-key ownership/modes stayed 0400; signing and fresh SSH to both
peers passed. This is warm verification only.[^startup-manual] The
[signing loader](git-signing-agent.md) separately checks local publication
once per second without spending its network-error backoff.

Host-specific file for [mini](../hosts/mini.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/mini/credential-startup.nix`](../../modules/hosts/mini/credential-startup.nix)

[^startup-manual]: Pinned sops-nix source inspection, unified log timestamps and NRS activation evidence.
