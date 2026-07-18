---
type: Overlay
title: gh-op
description: 'Linux-only gh wrapper sourcing GH_TOKEN from 1Password at runtime — via a vault-scoped service-account token when deployed, desktop-app auth otherwise — so ~/.config/gh/hosts.yml holds no plain-text token on nebula''s unencrypted disk.'
resource: overlays/gh-op.nix
tags: [overlay, secrets]
timestamp: '2026-07-04T05:22:04+00:00'
---

On Linux, wraps `gh` (symlinkJoin, so completions/man survive) to source its
token from 1Password at runtime — `GH_TOKEN` via `op read
"op://Automation/GitHub gh CLI token/credential"` — so `~/.config/gh/hosts.yml`
holds no plain-text token on nebula's unencrypted disk (the same
prefer-`op read`-over-at-rest-secrets stance as the sops age key handling).
This single wrapper covers every consumer: the CLI itself and git's
`!gh auth git-credential` credential helper (set in the stowed
[git](../modules/git.md) config) both resolve `gh` from PATH. On darwin, gh
passes through untouched (FileVault disks; hosts.yml is fine there).

Token resolution order (see
[op-service-account-token](../decisions/op-service-account-token.md) for the
security rationale):

1. An explicit `GH_TOKEN` in the environment wins; the wrapper only injects
   when it's unset.
2. If `/run/secrets/op-sa-token` is readable (sops secret declared in
   [nebula](../hosts/nebula.md)'s configuration.nix), the `op read` runs with
   `OP_SERVICE_ACCOUNT_TOKEN` set to it — no desktop-app authorization
   prompt, works with the app locked and headless. The SA token is scoped to
   that single `op read`, never exported into gh's environment.
3. Otherwise the plain interactive `op read` (desktop-app integration,
   biometric prompt).
4. If the read fails either way, fall through to hosts.yml behaviour — i.e.
   unauthenticated, gh's normal "not logged in" errors.

Operational facts:

- `op` is deliberately invoked by bare name — on NixOS the interactive path
  must resolve to the setgid security wrapper (`/run/wrappers/bin/op`, group
  `onepassword-cli`) or desktop-app integration breaks. Never hardcode the
  store path. (The SA path doesn't need the socket, but the invocation is
  identical.)
- `gh auth login/logout/refresh` skip injection (gh refuses to log in while
  `GH_TOKEN` is set), so re-authing still works; after a re-auth, move the new
  token into the 1Password item and `gh auth logout` to keep hosts.yml clean.
- Cost: one `op read` per gh invocation (~0.5s; the SA path is a network
  round-trip to 1Password.com, same ballpark).
- Rotation ~every 90d (token expires 2026-10-18, 1Password alert Oct 11):
  follow [rotate-op-sa-token](../playbooks/rotate-op-sa-token.md).

## Source

- Overlay: [`overlays/gh-op.nix`](../../overlays/gh-op.nix)

## Citations

- [1Password service accounts](https://developer.1password.com/docs/service-accounts/)
- [op CLI app-integration security model](https://developer.1password.com/docs/cli/app-integration-security/)
