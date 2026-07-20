---
type: Dual Module
title: Rtk
description: 'rtk — CLI proxy that filters dev command output (git, grep, cargo, npm, docker, aws, …) before it reaches an LLM''s context.'
resource: modules/darwin/rtk.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-19T00:06:40+00:00'
---

[rtk](https://github.com/rtk-ai/rtk) (Rust Token Killer) is a single-binary
CLI proxy that rewrites 100+ common dev commands (git, grep, cargo, npm,
docker, aws, …) to filtered/compacted output before it reaches an LLM's
context, claiming 60-90% token savings. Both twins install it onto
`environment.systemPackages`; the [rtk package](../packages/rtk.md) does the
build. The darwin twin additionally bridges rtk's config path: rtk resolves
user-global config/filters via Rust's `dirs::config_dir()`, which on macOS is
`~/Library/Application Support/rtk` (XDG ignored), so a `postActivation`
script (order 1600, after dotfiles-stow) symlinks
`{config,filters}.toml` there → the stowed `~/.config/rtk/` copies. Per-file,
not whole-dir, because rtk writes mutable data (`history.db`, tee output)
beside them — see the 2026-07-20 correction in the
[rtk nix/direnv filters decision](../decisions/rtk-nix-direnv-filters.md).

Mounted ungated on every host of both classes
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).
A cross-OS twin — parallel implementations in each class dir (see the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md)).

Installing the package alone does nothing for a shell — rtk only rewrites
commands once its hook is registered in the calling tool. For Claude Code
that's a one-time per-user `rtk init -g`, which patches the config dir's
`settings.json` with a `PreToolUse`/`Bash` hook running
`rtk hook claude` and drops `RTK.md` (referenced from that dir's
`CLAUDE.md` via `@RTK.md`) documenting the meta commands
(`rtk gain`, `rtk discover`, `rtk proxy <cmd>`). `init` honors
`$CLAUDE_CONFIG_DIR`, so on hosts running the
[claude-account-selector](claude-account-selector.md) it must be run once
per profile: `CLAUDE_CONFIG_DIR=~/.claude-<profile> rtk init -g --auto-patch`
(done 2026-07-20 on `k` for `~/.claude-me` and `~/.claude-work`). None of
that hook wiring is Nix-managed — it lives in the profile config dirs,
outside this repo.

rtk's own config (`~/.config/rtk/config.toml`, `filters.toml`) is a separate
[stow package](../patterns/stow-tree.md), `home/rtk/`, unrelated to this
module's `environment.systemPackages` install. Custom filter config extends
coverage to `nix`/`direnv` wrappers — see the
[rtk nix/direnv filters decision](../decisions/rtk-nix-direnv-filters.md).

## Source

- darwin module: [`modules/darwin/rtk.nix`](../../modules/darwin/rtk.nix)
- NixOS module: [`modules/nixos/rtk.nix`](../../modules/nixos/rtk.nix)

## Citations

- [rtk repository & README](https://github.com/rtk-ai/rtk)
- [rtk project site](https://www.rtk-ai.app)
