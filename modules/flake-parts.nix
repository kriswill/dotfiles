# Top-level flake-parts wiring for the Dendritic pattern.
# `flakeModules.modules` provides the `flake.modules.<class>.<name>` option
# (https://flake.parts/options/flake-parts-modules.html) into which every
# feature file under `modules/nixos/` merges its NixOS module. import-tree
# (`vic/import-tree`) auto-discovers every `.nix` file under `modules/` — except
# paths containing `/_` (so `modules/hosts/_nebula/` is skipped and pulled in by
# explicit `imports` instead).
{ inputs, ... }:
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
  systems = [ "x86_64-linux" ];
}
