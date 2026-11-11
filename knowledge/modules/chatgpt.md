---
type: NixOS Module
title: ChatGPT Desktop
description: 'Installs OpenAI''s ChatGPT desktop app (ChatGPT and Codex in one Electron app, Linux preview) on nebula from nixpkgs'' chatgpt package, wires the package''s user-tmpfiles cache-pruning rule, and pins Office/CSV defaults so its desktop entry can''t take them from LibreOffice.'
resource: modules/hosts/nebula/chatgpt.nix
tags: [nixos-module, host-specific]
generated: { by: claude-code/opus-5.5, at: 2026-11-08T12:20:00-08:00 }
sources:
  - id: openai-linux
    resource: https://learn.chatgpt.com/codex/linux/linux-app
    title: 'OpenAI: ChatGPT desktop app on Linux (packages, updates, Wayland)'
  - id: nixpkgs-chatgpt
    resource: https://github.com/NixOS/nixpkgs/tree/master/pkgs/by-name/ch/chatgpt
    title: 'nixpkgs pkgs/by-name/ch/chatgpt (package, launcher, user-tmpfiles rule)'
---

Adds `pkgs.chatgpt` to `environment.systemPackages`. The package is nebula's
only route to the app. OpenAI ships `.deb`, `.rpm` and an Arch installer,
each of which adds OpenAI's signed package repository. Linux updates come
only through that repository, and the app has no updater of its own there.
No AppImage or Flatpak exists.[^openai-linux] nixpkgs unpacks the `.deb`,
fixes its libraries for NixOS, and swaps the bundled `rg`, `node`,
`tectonic` and `codex` for nixpkgs builds.[^nixpkgs-chatgpt] New versions
arrive with the flake's nixpkgs bump. OpenAI publishes builds several times
a day, and nixpkgs bumps every few days, about a week behind.

**Two codex binaries.** The app runs nixpkgs' `codex`. The CLI on PATH is
OpenAI's standalone install (`~/.local/bin/codex` →
`~/.codex/packages/standalone/current`), which updates itself in the
background. Both use `~/.codex` (auth, config, sessions), so expect a
version gap of a few days. `pkgs.chatgpt.override { codex = null; }`
switches the app to the codex OpenAI bundled with it.
While nixpkgs' codex doesn't build,
[chatgpt-broken-deps](chatgpt-broken-deps.md) does exactly that.
[user-packages](user-packages.md) still provides the system `bwrap` the
standalone CLI's sandbox wants. The app's wrapper adds its own.

**Plugin cache.** The launcher copies the bundled plugins to
`~/.cache/chatgpt/bundled-plugins-v2/<store hash>`, one copy per version,
and holds a shared `flock` on the copy in use. The package ships
`share/user-tmpfiles.d/chatgpt.conf` (`e %C/chatgpt/bundled-plugins-v2 - - - 0`)
to prune the rest. NixOS doesn't read packages' `user-tmpfiles.d`
directories, and `systemd.user.tmpfiles` has no `packages` option, so the
module links the file to `/etc/xdg/user-tmpfiles.d/`. `/etc/xdg` is on the
user manager's `XDG_CONFIG_DIRS`, which `systemd-tmpfiles --user` honours
(checked with `--cat-config`). The daily user
`systemd-tmpfiles-clean.timer` does the pruning.

**MIME defaults.** `chatgpt.desktop` declares http/https, `codex://`, CSV/TSV
and the Excel, Word and PowerPoint types. Nothing set defaults for the
Office types. They resolved through `mimeinfo.cache` order, where
`chatgpt.desktop` sorts ahead of `impress`/`writer`, so .docx and .pptx
would have opened in ChatGPT. The [stow tree](../patterns/stow-tree.md)'s
`home/mimeapps/.config/mimeapps.list` now pins every Office/CSV type the
entry claims to LibreOffice. http/https were already pinned to Helium.

**Wayland.** The launcher adds `--ozone-platform=wayland` when
`NIXOS_OZONE_WL` is set, which snowglobe does on nebula, so the app runs
natively rather than under XWayland. OpenAI calls native Wayland
experimental: floating windows, positioning, focus and shortcuts may
misbehave.[^openai-linux]

Consumers of the shared `~/.codex` state: [ai-usage](ai-usage.md) (ChatGPT
plan limits) and [hermes-agent](nebula-hermes-agent.md) (`CODEX_HOME` login
import). Sibling desktop app installed the same way:
[jellyfin-desktop](jellyfin-desktop.md).

Host-specific file for [nebula](../hosts/nebula.md) — merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).

## Source

- Module: [`modules/hosts/nebula/chatgpt.nix`](../../modules/hosts/nebula/chatgpt.nix)

[^openai-linux]: OpenAI: ChatGPT desktop app on Linux (packages, updates, Wayland)
[^nixpkgs-chatgpt]: nixpkgs pkgs/by-name/ch/chatgpt (package, launcher, user-tmpfiles rule)
