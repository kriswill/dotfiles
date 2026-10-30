---
type: NixOS Module
title: Hermes Agent
description: 'Hermes Agent (Nous Research''s self-hosted AI agent: CLI/TUI plus a messaging/cron gateway) — re-exports the hermes-agent sub-flake''s single-owner NixOS module (services.hermes-agent, a trimmed copy of upstream''s) into the nixos class, inert until a host enables it.'
resource: modules/nixos/hermes-agent.nix
tags: [nixos-module, ai-agent]
generated: { by: claude-code/opus-5-5, at: 2026-10-30T03:00:00+00:00 }
sources:
  - id: hermes-nix-setup
    resource: https://hermes-agent.nousresearch.com/docs/getting-started/nix-setup
    title: 'Hermes Agent docs: Nix & NixOS Setup (options reference)'
  - id: subflake-readme
    resource: ../../flakes/hermes-agent/README.md
    title: 'flakes/hermes-agent/README.md (the module''s changes against upstream)'
---

One-line re-export of `inputs.hermes-agent.nixosModules.default`, the same
shape as [battlenet](battlenet.md). The module lives in the
[hermes-agent sub-flake](../packages/hermes-agent.md), copied from
upstream's v0.22.5 module and trimmed
([decision](../decisions/hermes-agent-vendored-nix.md)). It defaults
`services.hermes-agent.package` to the sub-flake's own package (every
portable optional integration: messaging, voice, anthropic, …), so there is
no overlay. The package is also re-exported in `modules/packages.nix`.

Upstream's options keep their meaning,[^hermes-nix-setup] except for
these:[^subflake-readme]

- `user` is required and never created, because Hermes is single-owner.
  `createUser` is gone. `group` (default `hermes`) is created with no
  members.
- State directories are `2750`, not `2770`, and activation adds no group
  write to files.
- `addToSystemPackages` installs a CLI wrapped with
  `--set-default HERMES_HOME`, so it works in shells that never read
  `environment.variables`.
- `herdr.enable` (new) adds herdr's integration plugin.
- `settings` lists concatenate across definitions.
- Container mode is gone. `backend.mode` (`hermes serve`/`dashboard`) stays.

Why the system service, and the history of each workaround:
[hermes-agent-system-service](../decisions/hermes-agent-system-service.md).

Enabled on [nebula](../hosts/nebula.md) by
[nebula-hermes-agent](nebula-hermes-agent.md); auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md) and mounted per
the [host-mounted modules pattern](../patterns/host-mounted-modules.md).

Gotcha: the module's activation script runs `lib.stringAfter [ "users"
"setupSecrets" ]` and copies `environmentFiles` into `$HERMES_HOME/.env` as
root, so a root-only (default 0400) sops secret is enough. The unit itself
never reads the secret path.

## Source

- Module: [`modules/nixos/hermes-agent.nix`](../../modules/nixos/hermes-agent.nix)
- Implementation: [`flakes/hermes-agent/nix/nixosModules.nix`](../../flakes/hermes-agent/nix/nixosModules.nix)
- Options under: `services.hermes-agent`

[^hermes-nix-setup]: Hermes Agent docs: Nix & NixOS Setup (options reference)
[^subflake-readme]: flakes/hermes-agent/README.md
