---
type: Darwin Module
title: Homebrew
description: 'nix-darwin''s homebrew module — declares the casks/brews/taps that must come from Homebrew rather than nixpkgs, with zap cleanup so anything not listed is uninstalled on rebuild.'
resource: modules/darwin/homebrew.nix
tags: [darwin-module]
timestamp: '2026-06-03T08:57:29-07:00'
---

Declarative Homebrew via nix-darwin: taps (`steipete/tap`, `marcus/tap`),
casks (rwts-pdfwriter, zerotier-one, 1password-cli, karabiner-elements,
launchcontrol) and brews (`td`, `sidecar`). Everything here is a thing nixpkgs
can't sensibly provide on macOS (GUI apps, kexts, PDF print services).

Gotchas that shape the config:

- `onActivation.cleanup = "zap"` — removing a cask from the list uninstalls
  **and zaps** it (app + its data) on the next rebuild. That's deliberate:
  the Brewfile is the single source of truth. The chromium cask was removed
  this way on 2026-07-10 (Helium replaced it; the
  [Helium Chrome shim](helium-chrome-shim.md) keeps Chrome-only tooling
  working).
- Homebrew ≥ 5.1 refuses `brew bundle --cleanup` non-interactively without a
  force flag, so `extraFlags = [ "--force-cleanup" ]` pre-authorizes the zap
  during activation.
- `masApps` (Xcode) is commented out — MAS installs are too slow for every
  rebuild.

Mounted ungated on every darwin host (see the [host-mounted modules pattern](../patterns/host-mounted-modules.md)), auto-discovered
via the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Module: [`modules/darwin/homebrew.nix`](../../modules/darwin/homebrew.nix)

## Citations

- nix-darwin homebrew options — <https://nix-darwin.github.io/nix-darwin/manual/index.html>
