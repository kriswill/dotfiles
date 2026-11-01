---
type: Dual Module
title: Herdr
description: 'Re-export of the herdr umbrella sub-flake''s NixOS and nix-darwin modules, with programs.herdr-cli on everywhere: herdr, the terminal agent multiplexer, built on both OSes from our kriswill/herdr fork (upstream v0.9.5 + our tab-bar and nested-shell commits), plus herdr-nav; the same modules mount programs.herdr-core, programs.herdr-app and services.herdr-update-check for hosts to opt into.'
resource: modules/darwin/herdr.nix
tags: [darwin-module, nixos-module, herdr]
generated: { by: claude-code/opus-5.5, at: 2026-11-01T14:00:00-08:00 }
sources:
  - id: herdr-project-site
    resource: https://herdr.dev
    title: herdr project site
  - id: herdr-repository
    resource: https://github.com/herdrdev/herdr
    title: herdr repository
  - id: subflake-readme
    resource: ../../flakes/herdr/README.md
    title: 'flakes/herdr/README.md (the TUI, modules, config files and stow)'
  - id: core-systemd-rs
    resource: https://github.com/herdrdev/herdr-core/blob/v0.1.16/crates/herdr-core/src/platform/systemd.rs
    title: 'herdr-core src/platform/systemd.rs (transient user units, linger())'
  - id: nixos-users-groups
    resource: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/users-groups.nix
    title: 'NixOS users-groups.nix (users.users.<name>.linger, linger-users service)'
  - id: app-persist-rs
    resource: https://github.com/herdrdev/herdr-app/blob/v0.1.11/src/persist.rs
    title: 'herdr-app src/persist.rs (write_atomic follows symlinks)'
---

[herdr](https://herdr.dev) is a terminal multiplexer for coding agents. It
runs several agents side by side in one terminal, in persistent sessions that
survive detach and can be reached over SSH.[^herdr-project-site] Each class
module here is two lines: it imports the [herdr sub-flake](../packages/herdr.md)'s
module for its OS (`nixosModules.herdr` / `darwinModules.herdr`) and sets
`programs.herdr-cli.enable = true`, so every host gets the TUI as before.

**The TUI comes from our fork.** It's built from upstream's `v0.9.5` stable
tag plus our commits (fork tag `v0.9.5-custom`), now through the sub-flake's
`herdr-cli` input. The fork ships its own flake, which builds from source
with no binary cache.[^herdr-repository] Our commits are the ANSI tab-bar
command entries (`argv`/`ansi` fields, plus `HERDR_TOKEN_*` env with reactive
re-runs), which replaced the earlier
[token-bar patch](../decisions/herdr-token-bar-patch.md), and opt-in
nested-shell agent detection.

The pin's history: preview tag `preview-2026-07-29-44b3adb12552`, then stable
`v0.8.0` the day upstream released it (2026-08-03), `v0.8.2` (2026-08-22),
the fork's `custom` branch (2026-08-30), its `v0.9.1-custom` tag
(2026-09-27), and per-release rebases since.

≥ v0.8.2 carries the CSI 14t/16t pixel-size fix
([#835](https://github.com/herdrdev/herdr/issues/835)) that nixpkgs' 0.7.5
lacks. Together with `experimental.kitty_graphics = true` in the stow
`config.toml`, it makes in-pane images render (fastfetch, yazi;
[`docs/fastfetch.md`](../../docs/fastfetch.md)).

nixpkgs' herdr doesn't matter here. Dropping the fork would mean upstreaming
the tab-bar change first, or losing the usage indicator, and it would revert
**both** OSes at once.

Rebasing: rebase `custom` onto each new upstream tag, tag it `vX.Y.Z-custom`,
and repoint `herdr-cli.url` in `flakes/herdr/flake.nix`. The sub-flake's
`herdr-update-check` flags each new release; it replaces the nebula-only
[herdr-update-check](herdr-update-check.md) unit.

The move into the sub-flake on 2026-11-01 left `herdr --version` and the drv
unchanged on nebula and the macs. The build identity, `pkgs.herdr` and
herdr-nav all came along ([decision](../decisions/herdr-umbrella-subflake.md)).
`pkgs.herdr` stayed overlaid for hermes-agent's `herdr.package`, which its
[TypeScript Herdr integration](../decisions/hermes-herdr-integration-shell-hook.md)
dropped, so nothing uses it now.

Options, all defined in the sub-flake's `modules/common.nix` plus per-OS
layers:[^subflake-readme]

- `programs.herdr-cli`:
  - `enable`, `package`.
  - `nav.enable` (default `true`) installs [herdr-nav](../packages/herdr-nav.md)
    with `package` pinned in it.
  - `python` (default `python3`, `null` for none) is for herdr's agent hooks.
    Claude's `herdr-agent-state.sh` reports the session id with python3 and
    exits silently without it, which would leave herdr unable to resume
    sessions. On the macs this avoids leaning on the Command Line Tools'
    `/usr/bin/python3`.
- `programs.herdr-core` (`hc`, upstream's release build):
  - `enable`, `package`.
  - `users`: they get the config links, the update check's unit, and on
    NixOS linger.
  - `settings` (TOML or `null`): `config.toml` as a store link.
  - `linger` (NixOS, default `true`) declares `users.users.<u>.linger`. hc
    runs `loginctl enable-linger` itself on first use,[^core-systemd-rs] so
    `false` means only "undeclared". Declaring linger off would have NixOS's
    `linger-users` service fight hc.[^nixos-users-groups]
- `programs.herdr-app` (Linux; the darwin module asserts it off):
  - `enable` installs `finalPackage`, which is `package` wrapped for
    `telemetry` (default off) and `settings`.
  - `settings` (merged into `settings.json` at launch, declared keys win) and
    `keys` (`keys.json`, as a link).
  - It also sets herdr-core and `hardware.graphics` on (`mkDefault`), and
    warns if the core is older than the app's `coreMin`.
  - With the core enabled, the wrapper pins Herdr's hc lookup to
    `programs.herdr-core.package`'s bin (`HERDR_CORE_DIRS`). Herdr leads every
    pane's PATH with the folder it found hc in, and the system profile there
    shadowed `/run/wrappers/bin`'s setuid `sudo`
    ([decision](../decisions/herdr-app-pin-core-dir.md)).
- `services.herdr-update-check`:
  - `enable`, `package`.
  - The schedule is a NixOS `calendar` (systemd user timer, `Type=exec`,
    `restartIfChanged = false`, `ConditionUser` for hc's users) or a darwin
    `startCalendarInterval` (launchd agent).
  - It checks only the enabled programs, against their configured packages'
    versions.

**File options default to null, which leaves the file alone.** Herdr's saves
write through symlinks,[^app-persist-rs] so stow can own the files and
version the app's edits. nebula does exactly that
([decision](../decisions/herdr-app-config-via-stow.md)). Given content, a
file becomes a store link: `systemd-tmpfiles` `L+` on NixOS, `ln -sfn` from
the activation script on darwin.

The TUI's own `config.toml` is the `home/herdr/`
[stow package](../patterns/stow-tree.md). It's adopted per file because
herdr keeps mutable runtime data (logs, sockets, `session.json`) in the same
`~/.config/herdr/`.

- **Keybindings** lean tmux-ward (`ctrl+space` prefix, `%`/`"` splits).
  `ctrl+h/j/k/l` pane focus goes through herdr-nav, so nvim keeps those keys
  inside its own splits
  ([decision](../decisions/vim-aware-pane-navigation.md)).
- **Usage bars.** Claude's weekly-usage bars at the tab bar's right edge come
  from an ANSI `command` entry running `~/.local/bin/dotbar-usage`. It draws
  the workspace metadata tokens that a statusline-spawned watcher publishes,
  as [dotbar](../packages/dotbar.md) braille bars
  ([ANSI tab-bar entries](../decisions/herdr-ansi-tab-bar-entries.md),
  [usage tab-bar indicator](../decisions/herdr-usage-tab-indicator.md)).

Darwin began as a plain nixpkgs entry in [user-packages](user-packages.md).
It became a twin when the flake pin extended to darwin, and the twins now
share one option set from the sub-flake, per the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md).
On [nebula](../hosts/nebula.md), [nebula-herdr](nebula-herdr.md) turns on the
app, the core and the update check.

Mounted ungated on every host
([host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Darwin module: [`modules/darwin/herdr.nix`](../../modules/darwin/herdr.nix) →
  [`flakes/herdr/modules/darwin.nix`](../../flakes/herdr/modules/darwin.nix)
- NixOS module: [`modules/nixos/herdr.nix`](../../modules/nixos/herdr.nix) →
  [`flakes/herdr/modules/nixos.nix`](../../flakes/herdr/modules/nixos.nix)
- Shared options: [`flakes/herdr/modules/common.nix`](../../flakes/herdr/modules/common.nix)

[^herdr-project-site]: herdr project site
[^herdr-repository]: herdrdev/herdr repository
[^subflake-readme]: `flakes/herdr/README.md`: the TUI, modules, config files and stow
[^core-systemd-rs]: herdr-core `src/platform/systemd.rs`: `spawn()` and `linger()`
[^nixos-users-groups]: NixOS `users-groups.nix`: the `linger` option and `systemd.services.linger-users`
[^app-persist-rs]: herdr-app `src/persist.rs`: `resolve_target`, `write_atomic` and their symlink tests
