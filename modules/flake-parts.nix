# Top-level flake-parts wiring for the Dendritic pattern.
# `flakeModules.modules` provides the `flake.modules.<class>.<name>` option
# (https://flake.parts/options/flake-parts-modules.html) into which every
# feature file merges its darwin / home-manager module.
{ inputs, ... }:
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
  systems = [ "aarch64-darwin" ];
}
