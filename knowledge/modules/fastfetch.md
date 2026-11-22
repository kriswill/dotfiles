---
type: Dual Module
title: Fastfetch
description: 'fastfetch — fast neofetch-style system-info fetcher; the twins re-export the fastfetch sub-flake''s module, so each host picks its logo image declaratively via programs.fastfetch.logo instead of config.jsonc, and install the wrapped build it produces.'
resource: modules/darwin/fastfetch.nix
tags: [darwin-module, nixos-module]
generated: { by: claude-code/fable-5-2, at: 2026-11-21T13:34:57-08:00 }
sources:
  - id: fastfetch-repository
    resource: https://github.com/fastfetch-cli/fastfetch
    title: fastfetch repository
  - id: fastfetch-logo-options
    resource: https://github.com/fastfetch-cli/fastfetch/wiki/Logo-options
    title: fastfetch logo options
---

[fastfetch](https://github.com/fastfetch-cli/fastfetch) prints system info
with an image logo. Both class modules import the
[fastfetch sub-flake](../packages/fastfetch.md)'s module, which declares
`programs.fastfetch.logo` (filename under the `home/fastfetch/` stow
package) plus `logoPaddingTop`, and builds a wrapped binary in its
`package.nix` (symlinkJoin + wrapProgram, the [diffnav](diffnav.md) idiom)
from the host's own `pkgs.fastfetch`, passing
`--logo "$HOME/.config/fastfetch/<logo>"` — CLI flags beat the stowed
`config.jsonc`, which deliberately carries no logo `source` (only the
`kitty-icat` type and the 27×20 render box). Each host sets the option
beside its registration: the Macs pick `hexley-nix.png` (Hexley the platypus
on the Nix snowflake; the darwin twin sets `logoPaddingTop = 3` by default
to vertically center the wide image), [nebula](../hosts/nebula.md) picks
`Nebula.png`.
Full protocol/terminal story: [`docs/fastfetch.md`](../../docs/fastfetch.md).

The sub-flake's module installs nothing; it exposes the build as
`programs.fastfetch.finalPackage`. The twins deliver it differently: darwin
adds it to `environment.systemPackages` (nix-darwin has no fastfetch
module), while the nixos side swaps it in through snowglobe-factory's own
`programs.fastfetch.package` option — snowglobe already installs fastfetch,
so the sub-flake's `logo`/`logoPaddingTop`/`finalPackage` declarations merge
into its option set and no colliding second copy ships. The `kitty-icat` logo type shells out to
[kitten](../packages/kitten.md) on both OSes.

The wrapper also puts a `kitten` shim first on fastfetch's PATH
(`flakes/fastfetch/kitten-shim.sh`). fastfetch's kitten arguments are fixed,
and in a [Herdr](herdr.md) app pane they draw nothing: the pty reports no
pixel size, and inside `devenv shell` kitten picks a file handoff Herdr
refuses. There the shim adds `--use-window-size` and
`--transfer-mode=stream`; every other call reaches the real kitten
unchanged ([decision](../decisions/fastfetch-kitten-shim.md)).

Mounted ungated on every host (see the [host-mounted modules
pattern](../patterns/host-mounted-modules.md)) per the [cross-OS module
twins pattern](../patterns/cross-os-module-twins.md); auto-discovered via
the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Darwin module: [`modules/darwin/fastfetch.nix`](../../modules/darwin/fastfetch.nix)
- NixOS module: [`modules/nixos/fastfetch.nix`](../../modules/nixos/fastfetch.nix)
- The module both import: [`flakes/fastfetch/module.nix`](../../flakes/fastfetch/module.nix)
- Wrapper: [`flakes/fastfetch/package.nix`](../../flakes/fastfetch/package.nix)
- kitten shim for Herdr panes: [`flakes/fastfetch/kitten-shim.sh`](../../flakes/fastfetch/kitten-shim.sh)
- Stow package: [`home/fastfetch/`](../../home/fastfetch/) — see the [stow tree pattern](../patterns/stow-tree.md)
