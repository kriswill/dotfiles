---
type: Dual Module
title: Ai Usage
description: 'Runs the ai-usage collector daemon (Claude Max limits, Anthropic API cost, ChatGPT/Codex limits) as a systemd user service on nebula and an opt-in launchd agent on the macs, feeding the herdr-app ai-usage sidebar panel.'
resource: modules/darwin/ai-usage.nix
tags: [darwin-module, nixos-module, herdr]
generated: { by: claude-code/opus-5.5, at: 2026-11-01T16:05:00-08:00 }
sources:
  - id: nixos-systemd-user-services
    resource: https://search.nixos.org/options?channel=unstable&query=systemd.user.services
    title: NixOS `systemd.user.services` options
  - id: nix-darwin-manual
    resource: https://nix-darwin.github.io/nix-darwin/manual/index.html
    title: nix-darwin manual (`launchd.user.agents`)
  - id: op-read
    resource: https://developer.1password.com/docs/cli/reference/commands/read/
    title: 1Password CLI `op read`
---

Both twins install [ai-usage](../packages/ai-usage.md) and run `ai-usage
daemon`, which writes `~/.cache/ai-usage/usage.json` for the herdr-app
`ai-usage` mod and for `ai-usage` in a terminal. Why a daemon and a draw-only
mod: [decision](../decisions/ai-usage-collector-daemon.md).

- **NixOS** (ungated): a user unit wanted by `graphical-session.target`,
  not `default.target`.[^nixos-systemd-user-services] k's user manager
  lingers from boot for herdr-core ([herdr](herdr.md)), and the Admin key's
  `op read` needs the 1Password desktop app.[^op-read] `PATH` is forced to
  reach `/run/wrappers/bin` for the setgid `op`, which is never pinned.
  A rebuild doesn't restart user units, so new code needs
  `systemctl --user restart ai-usage`.
- **darwin** (`services.ai-usage.enable`, on [k](../hosts/k.md) since
  2026-11-01, off on mini and SOC-Kris-Williams): a
  launchd agent with `KeepAlive`, logging to `~/Library/Logs/ai-usage.log`,
  `PATH` reaching Homebrew's `op`.[^nix-darwin-manual] Claude's login comes
  from the keychain via `/usr/bin/security`.

Accounts, labels, prices, budgets and the Admin key's 1Password reference
live in the cross-OS `ai-usage` stow package, so editing them needs no
rebuild; the daemon rereads the config on every pass.

Imported on every darwin host but disabled by default — hosts opt in with `services.ai-usage.enable = true;` (k does);
mounted ungated on every NixOS host
(see the [host-mounted modules pattern](../patterns/host-mounted-modules.md));
auto-discovered via the [Dendritic module layout](../patterns/dendritic-modules.md).
A cross-OS twin — parallel implementations in each class dir (see the
[cross-OS module twins pattern](../patterns/cross-os-module-twins.md)).

## Source

- darwin module: [`modules/darwin/ai-usage.nix`](../../modules/darwin/ai-usage.nix)
- NixOS module: [`modules/nixos/ai-usage.nix`](../../modules/nixos/ai-usage.nix)
- Options under: `services.ai-usage` (darwin)
- Stow package: [`home/ai-usage/`](../../home/ai-usage/) — see the [stow tree pattern](../patterns/stow-tree.md)
- herdr-app mod: [`home/herdr-app/.config/herdr-app/mods/ai-usage/`](../../home/herdr-app/.config/herdr-app/mods/ai-usage/main.js), placed in the `personal` layout's sidebar

[^nixos-systemd-user-services]: NixOS `systemd.user.services` options
[^nix-darwin-manual]: nix-darwin manual (`launchd.user.agents`)
[^op-read]: 1Password CLI `op read`
