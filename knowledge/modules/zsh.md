---
type: Dual Module
title: Zsh
description: 'Zsh with ZDOTDIR moved to ~/.config/zsh (exported from shellInit so it precedes .zshrc lookup), XDG history placement, starship-owned prompt, and the tools the stowed .zshrc calls by bare name.'
resource: modules/darwin/zsh.nix
tags: [darwin-module, nixos-module]
timestamp: '2026-07-03T12:00:00-07:00'
---

Configures `programs.zsh` on both OSes: `ZDOTDIR` is exported to
`~/.config/zsh` from `shellInit` — i.e. from the nix-generated `/etc/zshenv`,
so it takes effect before `.zshrc` lookup and `.zcompdump` placement;
`histSize = 100000` with the history file under `~/.local/state/zsh`; and
`promptInit = lib.mkForce ""` because starship owns the prompt. It also
installs the tools the stowed `.zshrc` (`home/zsh/`) invokes by bare name
(eza, starship, zoxide, hstr, bat-extras.batman), sets `LESSHISTFILE` under
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

Mounted ungated on every host (see the
[host-mounted modules pattern](../patterns/host-mounted-modules.md)),
auto-discovered via the
[Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- darwin module: [`modules/darwin/zsh.nix`](../../modules/darwin/zsh.nix)
- NixOS module: [`modules/nixos/zsh.nix`](../../modules/nixos/zsh.nix)
- Stow package: [`home/zsh/`](../../home/zsh/) — see the [stow tree pattern](../patterns/stow-tree.md)
