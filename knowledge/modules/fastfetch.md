---
type: Dual Module
title: Fastfetch
description: fastfetch — fast neofetch-style system-info fetcher; both OSes wrap the binary so each host picks its logo image declaratively via programs.fastfetch.logo instead of config.jsonc.
resource: modules/darwin/fastfetch.nix
tags: [darwin-module, nixos-module]
generated: { by: okflight/0.4.0, at: 2026-06-11T16:31:03-07:00 }
sources:
  - id: fastfetch-repository
    resource: https://github.com/fastfetch-cli/fastfetch
    title: fastfetch repository
  - id: fastfetch-logo-options
    resource: https://github.com/fastfetch-cli/fastfetch/wiki/Logo-options
    title: fastfetch logo options
---

[fastfetch](https://github.com/fastfetch-cli/fastfetch) prints system info
with an image logo. Both class modules declare `programs.fastfetch.logo`
(filename under the `home/fastfetch/` stow package) plus `logoPaddingTop`,
and build a wrapped binary through `lib/fastfetch-logo-wrapper.nix`
(symlinkJoin + wrapProgram, the [diffnav](diffnav.md) idiom) passing
`--logo "$HOME/.config/fastfetch/<logo>"` — CLI flags beat the stowed
`config.jsonc`, which deliberately carries no logo `source` (only the
`kitty-icat` type and the 27×20 render box). Each host sets the option
beside its registration: the Macs pick `hexley-nix.png` (Hexley the platypus
on the Nix snowflake; darwin defaults `logoPaddingTop = 3` to vertically
center the wide image), [nebula](../hosts/nebula.md) picks `Nebula.png`.
Full protocol/terminal story: [`docs/fastfetch.md`](../../docs/fastfetch.md).

The twins deliver the wrapper differently: darwin adds it to
`environment.systemPackages` (nix-darwin has no fastfetch module), while the
nixos side swaps it in through snowglobe-factory's own
`programs.fastfetch.package` option — snowglobe already installs fastfetch,
so our `logo`/`logoPaddingTop` declarations merge into its option set and no
colliding second copy ships. The `kitty-icat` logo type shells out to
[kitten](../packages/kitten.md) on both OSes.

Mounted ungated on every host (see the [host-mounted modules
pattern](../patterns/host-mounted-modules.md)) per the [cross-OS module
twins pattern](../patterns/cross-os-module-twins.md); auto-discovered via
the [Dendritic module layout](../patterns/dendritic-modules.md).

## Source

- Darwin module: [`modules/darwin/fastfetch.nix`](../../modules/darwin/fastfetch.nix)
- NixOS module: [`modules/nixos/fastfetch.nix`](../../modules/nixos/fastfetch.nix)
- Shared wrapper builder: [`lib/fastfetch-logo-wrapper.nix`](../../lib/fastfetch-logo-wrapper.nix)
- Stow package: [`home/fastfetch/`](../../home/fastfetch/) — see the [stow tree pattern](../patterns/stow-tree.md)
