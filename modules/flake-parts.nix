# Top-level flake-parts wiring for the Dendritic pattern.
# `flakeModules.modules` provides the `flake.modules.<class>.<name>` option
# (https://flake.parts/options/flake-parts-modules.html) into which every
# feature file under `modules/darwin/` / `modules/nixos/` merges its module.
# import-tree (`vic/import-tree`) auto-discovers every `.nix` file under
# `modules/` and feeds each to flake-parts as a module. (It skips paths
# containing `/_`; host config is wrapped as flake-parts modules instead.)
{ inputs, ... }:
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
  systems = [
    "aarch64-darwin" # k, mini, SOC-Kris-Williams
    "x86_64-linux" # nebula
  ];
}
