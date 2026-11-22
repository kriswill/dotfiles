# fastfetch on nix-darwin: the ./flakes/fastfetch module
# (flakes/fastfetch/module.nix), re-exported into the Dendritic module set.
# It brings programs.fastfetch.logo and .logoPaddingTop, which each host sets
# beside its registration, and builds .finalPackage: this system's
# pkgs.fastfetch wrapped with those flags and the kitten shim that makes the
# logo draw in Herdr panes (docs/fastfetch.md).
#
# The sub-flake's module installs nothing, and nix-darwin has no fastfetch
# module of its own, so the wrapped build goes into
# environment.systemPackages here. NixOS twin: modules/nixos/fastfetch.nix.
{ inputs, ... }:
{
  flake.modules.darwin.fastfetch =
    { config, lib, ... }:
    {
      imports = [ inputs.fastfetch.darwinModules.fastfetch ];

      programs.fastfetch = {
        logo = lib.mkDefault "hexley-nix.png";
        # Hexley is wide: width-fit leaves ~13 rows beside ~19 rows of
        # output, so drop it toward vertical center.
        logoPaddingTop = lib.mkDefault 3;
      };

      environment.systemPackages = [ config.programs.fastfetch.finalPackage ];
    };
}
