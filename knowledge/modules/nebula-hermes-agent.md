---
type: NixOS Module
title: Hermes Agent (nebula)
description: 'Enables services.hermes-agent on nebula, running the gateway as k from /var/lib/hermes, with the module''s HERMES_HOME-defaulting CLI (addToSystemPackages) so the CLI and the service share one single-owner HERMES_HOME, plus herdr''s integration plugin; the Anthropic key arrives through the hermes-env sops secret.'
resource: modules/hosts/nebula/hermes-agent.nix
tags: [nixos-module, host-specific, ai-agent, secrets]
generated: { by: claude-code/opus-5-5, at: 2026-10-30T03:00:00+00:00 }
sources:
  - id: hermes-nix-setup
    resource: https://hermes-agent.nousresearch.com/docs/getting-started/nix-setup
    title: 'Hermes Agent docs: Nix & NixOS Setup'
  - id: hermes-providers
    resource: https://hermes-agent.nousresearch.com/docs/integrations/providers
    title: 'Hermes Agent docs: LLM and Model Providers'
  - id: sops-nix
    resource: https://github.com/Mic92/sops-nix
    title: sops-nix
---

Turns on [hermes-agent](hermes-agent.md) for [nebula](../hosts/nebula.md),
merged into the host per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md). The
reasoning is in
[hermes-agent-system-service](../decisions/hermes-agent-system-service.md);
the workarounds below live in the
[hermes-agent sub-flake](../packages/hermes-agent.md)'s module since
[hermes-agent-vendored-nix](../decisions/hermes-agent-vendored-nix.md), so
this file only sets options.

- **One owner: k.** `user = "k"`. The module never creates the account, and
  its `hermes` group has no members, so the state dir and its `0640` `.env`
  stay off the shared `users` group. Upstream's default `hermes` system user
  can't share a home with k: hermes chmods `HERMES_HOME` to `0700` and forces `0600` plus
  same-uid checks onto `state.db`, `auth.json` and its locks. This was
  reproduced on a two-uid bench (see the decision); the `storage_unavailable`
  k saw had a different cause, the stray `~/.hermes` below. The unit keeps
  `ProtectSystem=strict` with `ReadWritePaths` limited to `/var/lib/hermes`,
  so the gateway reads with k's access but writes only its state.
- **State is shared.** k's CLI/TUI and the gateway see one set of sessions,
  skills, memory and cron in `/var/lib/hermes/.hermes`. There is no
  `~/.hermes`. The CLI creates sessions through the gateway, which refuses a
  cwd it can't see; as k it sees k's projects.
- **The CLI is wrapped** (`addToSystemPackages = true`). Upstream's option
  relied on `environment.variables` alone, which never reaches shells under
  a running session: they inherit `__NIXOS_SET_ENVIRONMENT_DONE=1`, and so does
  herdr's long-lived server. With `HERMES_HOME` unset, `hermes` silently
  created an unmanaged `~/.hermes` whose local gateway failed every session
  with `storage_unavailable` (`restore_policy: invalid policy`). The sub-flake's
  module now wraps every binary (`hermes`, `hermes-agent`, `hermes-acp`) in
  a `hermes-agent-cli` symlinkJoin with `--set-default HERMES_HOME`. The
  variable is still exported for fresh shells.
- **`HERMES_HOME` is `2750`, not upstream's `2770`.** The CLI refuses a
  group-writable home unless its group is the owner's private group
  (`unsafe_control_permissions … chmod go-w`). The module's tmpfiles rules
  and activation set `2750` on the state directories; the first cut needed
  a host-side `chmod g-w` snippet after upstream's `2770`.
- **Config is declarative.** `settings` renders `config.yaml`, deep-merged on
  each activation: Nix keys win, keys added at runtime survive. `hermes
  setup`, `hermes config set/edit` and `hermes gateway install` are refused
  under the module's managed mode.[^hermes-nix-setup]
- **Model.** `provider = "anthropic"`, `default = "claude-opus-5-5"`, billed
  per token via `ANTHROPIC_API_KEY`. The Claude-subscription OAuth path needs
  Max plus purchased extra-usage credits.[^hermes-providers] Hermes v0.22.5
  already lists Opus 5.5 as a mandatory-thinking model.
- **Secret.** `sops.secrets.hermes-env` (root, 0400) holds
  `ANTHROPIC_API_KEY=…`, sourced from the 1Password item "Antropic API Key
  (nebula-hermes)" (Private vault, field `password`). sops-nix's build-time
  manifest check fails the whole toplevel build (`the key 'hermes-env'
  cannot be found`) while the key is missing from
  `secrets.yaml`.[^sops-nix] Rotate it in memory, as in
  [rotate-op-sa-token](../playbooks/rotate-op-sa-token.md):

  ```sh
  export SOPS_AGE_KEY=$(op item get "nebula sops-age key" --format json --reveal \
    | jq -r '.fields[] | select(.label=="keys.txt").value' \
    | grep -o 'AGE-SECRET-KEY-[A-Z0-9]*')
  key=$(op read "op://Private/5vc22h6o6tzhj4tc6gto2a647m/password")
  sops set modules/hosts/nebula/secrets.yaml '["hermes-env"]' "\"ANTHROPIC_API_KEY=$key\""
  ```

- **herdr integration** (`herdr.enable = true`). The module runs
  `herdr.package`'s (the pinned herdr's) `herdr integration install hermes`
  against a build-time `HERMES_HOME` and keeps the generated
  `herdr-agent-state` plugin, so it tracks herdr bumps. The
  `hermes-agent-herdr-plugin` activation snippet links it at herdr's own
  path, `plugins/herdr-agent-state`, replacing whatever is there (such as a
  copy herdr installed by hand), and adds it to `settings.plugins.enabled`. It deliberately skips `extraPlugins`,
  which would name it `nix-managed-*`: at herdr's path, `herdr integration
  status` reports it `current`, and an install from herdr's settings tab
  fails with `Read-only file system` instead of writing a second copy (it
  still installs normally if the link is absent). In a herdr pane, the
  plugin reports the session id with `herdr pane report-agent-session`, so
  herdr can resume Hermes sessions. herdr's server only resolves
  `HERMES_HOME` if it started after the variable reached the session;
  otherwise it looks in `~/.hermes`.
- **No linger.** `users.users.k.linger` stays unset. The gateway starts at
  boot, before k's user manager exists, so cron runs unscoped workers rather
  than restart-safe `systemd-run --user` scopes until the gateway restarts
  inside a session. Set `linger = true` on k if cron jobs must survive
  gateway restarts.
- **Verify.** `systemctl status hermes-agent`, `journalctl -u hermes-agent -f`,
  `hermes config` (shows the rendered config), `hermes -z hi` (one-shot run).

## Source

- Module: [`modules/hosts/nebula/hermes-agent.nix`](../../modules/hosts/nebula/hermes-agent.nix)

[^hermes-nix-setup]: Hermes Agent docs: Nix & NixOS Setup
[^hermes-providers]: Hermes Agent docs: LLM and Model Providers
[^sops-nix]: sops-nix
