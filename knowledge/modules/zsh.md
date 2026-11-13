---
type: Dual Module
title: Zsh
description: 'Zsh with ZDOTDIR moved to ~/.config/zsh (exported from shellInit so it precedes .zshrc lookup), XDG history placement, starship-owned prompt, and the tools the stowed .zshrc calls by bare name.'
resource: modules/darwin/zsh.nix
tags: [darwin-module, nixos-module]
generated: { by: codex/gpt-6, at: 2026-11-13T13:42:00-08:00 }
sources:
  - id: shell-startup-manual
    resource: ../../docs/shell-startup-performance.md
    title: Zsh startup performance and macOS upgrade recovery
---

Configures `programs.zsh` on both OSes: `ZDOTDIR` is exported to
`~/.config/zsh` from `shellInit` — i.e. from the nix-generated `/etc/zshenv`,
so it takes effect before `.zshrc` lookup and `.zcompdump` placement;
`histSize = 100000` with the history file under `~/.local/state/zsh`; and
`promptInit = lib.mkForce ""` because starship owns the prompt. It also
installs the tools the stowed `.zshrc` (`home/zsh/`) invokes by bare name
(eza, starship, zoxide, atuin, bat-extras.batman), sets `LESSHISTFILE` under
XDG state, and pre-creates `~/.config/zsh`, `~/.local/state/zsh`, and
`~/.local/state/less`.

`darwin.zsh` (part of the stowed `home/zsh/` package, so darwin-only at
runtime despite living in the shared tree) caches two `eval "$(cmd)"`-style
shell integrations whose output is deterministic and expensive to
regenerate — `determinate-nixd completion zsh` and `brew shellenv` — to
files in `$ZDOTDIR`, refreshed only when the underlying binary's mtime is
newer than the cache. See
[cache-brew-shellenv](../decisions/cache-brew-shellenv.md) and the
[shell-startup-performance manual](../../docs/shell-startup-performance.md)
for the profiling that motivated it.

`session-env.zsh` (also stowed, Linux-only and skipped over SSH) fixes the
graphical-session variables (`WAYLAND_DISPLAY`, `DISPLAY`,
`HYPRLAND_INSTANCE_SIGNATURE`, …) before each command when they are missing
or point at a dead session. It copies them from
`systemctl --user show-environment`. herdr panes need this because they
inherit the environment of hc's lingering core, which can predate Hyprland.
See [herdr-pane-session-env](../decisions/herdr-pane-session-env.md).

Inside [Herdr](herdr.md) panes (`HC_TERMINAL_ID` or `HERDR_ENV=1`), the
stowed `.zshrc` defaults `HERMES_TUI` to `1`, selecting
[Hermes](hermes-agent.md)' resize-aware TUI without changing its global
configuration. An existing environment value is preserved; `hermes --cli`
overrides it for one invocation. New shells pick this up without a rebuild.
The condition scopes where the default is assigned, not inheritance: child
processes retain the exported value unless they override or unset it.

Side effect of ZDOTDIR worth knowing: `~/.zshrc` is never read by zsh, so
the stow tree ships one anyway as a PATH shim for GUI apps that parse it —
see [GUI Path](gui-path.md).

## macOS upgrade recovery

An OS upgrade can replace `/etc/zshrc` and `/etc/zprofile` with regular
files while `/etc/zshenv` remains managed. The user rc then runs without
`compinit`, producing `command not found: compdef`; autosuggestions and
syntax highlighting disappear, and history moves to `$ZDOTDIR/.zsh_history`.
This was reproduced on [mini](../hosts/mini.md) after macOS 27.2.1.

Preserve the replacement files and older `*.before-nix-darwin` backups,
then run [nrs](nrs.md) from a terminal with working sudo authentication to
restore the managed links. Open fresh shells afterward. `nrs --status`
does not detect this file drift; the
[startup manual](../../docs/shell-startup-performance.md#completion-errors-after-a-macos-upgrade)
records the inspection and verification steps.[^shell-startup-manual]

## Twin differences

Darwin additionally sets `enableAutosuggestions`/`enableSyntaxHighlighting`
(nix-darwin options; the nixos twin sets neither — either provided by
snowglobe profiles or a real feature gap, currently undocumented) and wraps
its history settings in `mkDefault` where nixos sets them plain. The zsh/less
state and config directories are pre-created per class via the same
mechanisms as [store-path configs](../patterns/store-path-configs.md) (nixos
with explicit 0755/0700 modes), and `LESSHISTFILE` goes through
`environment.variables` vs `environment.sessionVariables`. Package lists in
sync (all five identical); see the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md).

Darwin also appends `/nix/var/nix/profiles/system/sw/bin` from `shellInit`,
without subprocesses or duplicate entries. SSH commands can then find
[Herdr](herdr.md) before [boot activation](boot-activation.md) creates
`/run/current-system`; inherited project PATH priorities remain intact.
The fallback previously lived only in interactive `.zshrc`, missing the
first connection after [mini](../hosts/mini.md)'s reboot. See
[Darwin early boot](../decisions/darwin-early-boot.md) and the measured
[startup timeline](../../docs/shell-startup-performance.md#mini-reboot-timeline-2026-11-13-generation-25).

Mounted ungated on every host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- darwin module: [`modules/darwin/zsh.nix`](../../modules/darwin/zsh.nix)
- NixOS module: [`modules/nixos/zsh.nix`](../../modules/nixos/zsh.nix)
- Stow package: [`home/zsh/`](../../home/zsh/) — see the [stow tree pattern](../patterns/stow-tree.md)

[^shell-startup-manual]: Machine-verified startup diagnosis on mini, 2026-11-13.
