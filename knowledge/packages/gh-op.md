---
type: Overlay
title: gh-op
description: 'Linux-only gh wrapper sourcing GH_TOKEN from 1Password at runtime, so ~/.config/gh/hosts.yml holds no plain-text token on nebula''s unencrypted disk.'
resource: overlays/gh-op.nix
tags: [overlay, secrets]
timestamp: '2026-07-04T05:22:04+00:00'
---

On Linux, wraps `gh` (symlinkJoin, so completions/man survive) to source its
token from 1Password at runtime — `GH_TOKEN` via `op read
"op://Private/GitHub gh CLI token/credential"` — so `~/.config/gh/hosts.yml`
holds no plain-text token on nebula's unencrypted disk (the same
prefer-`op read`-over-at-rest-secrets stance as the sops age key handling).
This single wrapper covers every consumer: the CLI itself and git's
`!gh auth git-credential` credential helper (set in the stowed
[git](../modules/git.md) config) both resolve `gh` from PATH. On darwin, gh
passes through untouched (FileVault disks; hosts.yml is fine there).

Operational facts:

- `op` is deliberately invoked by bare name — on NixOS it must resolve to the
  setgid security wrapper (`/run/wrappers/bin/op`, group `onepassword-cli`) or
  desktop-app integration breaks. Never hardcode the store path.
- `gh auth login/logout/refresh` skip injection (gh refuses to log in while
  `GH_TOKEN` is set), so re-authing still works; after a re-auth, move the new
  token into the 1Password item and `gh auth logout` to keep hosts.yml clean.
- Failure mode: if `op read` fails (1Password app locked, approval declined),
  the wrapper falls through to hosts.yml behaviour — i.e. unauthenticated,
  with gh's normal "not logged in" errors. Cost: one `op read` (~0.5s) per gh
  invocation.
- An explicit `GH_TOKEN` in the environment wins; the wrapper only injects
  when it's unset.

## Source

- Overlay: [`overlays/gh-op.nix`](../../overlays/gh-op.nix)
