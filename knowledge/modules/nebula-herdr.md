---
type: NixOS Module
title: Herdr on nebula
description: 'nebula''s herdr settings: enables the Herdr desktop app and hc for k with linger declared and telemetry off, plus the daily herdr-update-check timer (the fork, core and app), leaving every config file to the home/herdr-core and home/herdr-app stow packages.'
resource: modules/hosts/nebula/herdr.nix
tags: [nixos-module, host-specific, herdr]
generated: { by: claude-code/opus-5.5, at: 2026-11-01T14:00:00-08:00 }
sources:
  - id: subflake-readme
    resource: ../../flakes/herdr/README.md
    title: 'flakes/herdr/README.md (config files and stow, updating)'
---

On top of the TUI that [herdr](herdr.md) installs everywhere, nebula turns on
`programs.herdr-app.enable`, `programs.herdr-core.users = [ "k" ]` (linger is
declared by the module's default) and `services.herdr-update-check.enable`.

Choices:

- **Config through stow, not Nix.** No file option is set.
  - `home/herdr-core` holds a commented `config.toml` with every key at its
    default.
  - `home/herdr-app` holds a `settings.json` seeded with
    `{"telemetry": false}`, so the link exists before the first launch and
    every Settings-screen save or zoom change lands in the repo.
  - `keys.json`, layouts and themes are captured when first customized, with
    `dots-adopt herdr-app .config/herdr-app/<file>`.
  - Both packages are darwin-skipped until the macs enable them
    ([decision](../decisions/herdr-app-config-via-stow.md)).
- **Linger on.** It was confirmed while choosing the design: hc wants it and
  would set it anyway. k's user manager now starts at boot, so
  `default.target`'s timers can fire before login. herdr-update-check waits
  for a notification daemon for that reason.
- **One update check.** It replaces nebula's old fork-only unit
  ([herdr-update-check](herdr-update-check.md), now deprecated) under the same
  unit name. It reports upstream releases past the fork and `sources.json`,
  and stale running builds.
  - For the fork: rebase and retag it, then repoint `herdr-cli.url`.
  - For the core and app: `bun flakes/herdr/update.ts`, then `nrs`.
  - After an `nrs` that bumped anything, run `herdr-update-check` by hand to
    catch a herdr server, core or window that needs
    restarting.[^subflake-readme]

Host-specific file for [nebula](../hosts/nebula.md), merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/herdr.nix`](../../modules/hosts/nebula/herdr.nix)

[^subflake-readme]: `flakes/herdr/README.md`: config files and stow; updating and upgrade notices
