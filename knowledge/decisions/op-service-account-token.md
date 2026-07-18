---
type: Decision
title: Use a 1Password Service-Account Token for Non-Interactive op Reads
description: 'A vault-scoped, expiring 1Password service-account token (sops → /run/secrets/op-sa-token) replaces per-tty desktop-app authorization for the gh wrapper''s op read, trading no at-rest secrecy nebula ever had for prompt-free operation plus audit, revocation, and expiry.'
tags: [secrets, 1password]
timestamp: '2026-07-18T23:45:00+00:00'
---

**Status:** active. **Where:** [gh-op](../packages/gh-op.md),
[nebula](../hosts/nebula.md).

## Context

The desktop-app integration that [gh-op](../packages/gh-op.md) relied on
authorizes `op` per terminal session (keyed on tty + process start time),
with a hard 10-minute idle timeout and 12-hour cap — none of it
configurable. Agent-driven shells (Claude Code Bash calls) and new tmux
panes each count as fresh sessions, so every few `gh`/`op read` invocations
raised another authorization prompt. 1Password offers exactly one
non-interactive alternative: service-account tokens.

## Decision

- A dedicated **Automation** vault holds only the "GitHub gh CLI token" item
  (moved out of Private — service accounts cannot be granted Private anyway).
- Service account **`nebula-gh`**: read-only on Automation, 90-day expiry
  (expires 2026-10-18). Its token is banked in the Automation-vault item
  "Service Account Auth Token: nebula-gh" (`op://` refs need the item *ID* —
  the `:` in the name is illegal in a secret reference).
- The token lands in `modules/hosts/nebula/secrets.yaml` via `sops set`
  (value piped from `op read`, never written plaintext or into a
  transcript; `SOPS_AGE_KEY` sourced in-memory from the "nebula sops-age
  key" 1Password item) and is declared in nebula's `configuration.nix` →
  `/run/secrets/op-sa-token`, owner `k`, mode 0400.
- The gh-op wrapper prefers it, scoped per-`op read`; interactive
  desktop-app auth remains the fallback, and everything else (sudo, SSH
  signing, ad-hoc Private-vault reads) stays on the biometric path.

## Consequences

- `gh` works prompt-free, headless, and with the 1Password app locked.
- **At-rest honesty:** nebula's disk is unencrypted and its sops age key
  derives from the on-disk SSH host key, so the SA token at rest is
  recoverable — equivalent to storing the gh token itself. The vault
  scoping makes that worst case identical to the pre-wrapper hosts.yml
  status quo, while adding an audit log, one-click revocation at
  1password.com, central rotation of the gh token, and the 90-day expiry as
  a compromise backstop. Disk encryption would strictly improve this design.
- Do not add other items to the Automation vault without re-running this
  analysis — the vault's one-item contents ARE the blast radius.
- Rotation is a manual ~90-day chore (tokens never auto-refresh); the
  procedure is [rotate-op-sa-token](../playbooks/rotate-op-sa-token.md).
  Service accounts can't be rotated or deleted via `op` CLI — web UI only.

## Citations

- [Manage service accounts](https://developer.1password.com/docs/service-accounts/manage-service-accounts/) — rotation, expiry
- [op CLI app-integration security](https://developer.1password.com/docs/cli/app-integration-security/) — the per-tty/10-min/12-h limits this routes around
- `overlays/gh-op.nix`, `modules/hosts/nebula/configuration.nix`, `modules/hosts/nebula/secrets.yaml`
