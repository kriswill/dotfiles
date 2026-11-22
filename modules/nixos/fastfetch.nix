# fastfetch on NixOS: the ./flakes/fastfetch module
# (flakes/fastfetch/module.nix), re-exported into the Dendritic module set.
# It brings programs.fastfetch.logo and .logoPaddingTop, which each host sets
# beside its registration, and builds .finalPackage: this system's
# pkgs.fastfetch wrapped with those flags and the kitten shim that makes the
# logo draw in Herdr panes (docs/fastfetch.md).
#
# The sub-flake's module installs nothing. snowglobe-factory already installs
# fastfetch through its own programs.fastfetch options
# (enable/package/installGlobally), so the wrapped build goes in through its
# `package` option and no second copy ships to collide with the first.
# Darwin twin: modules/darwin/fastfetch.nix.
{ inputs, ... }:
{
  flake.modules.nixos.fastfetch =
    { config, lib, ... }:
    {
      imports = [ inputs.fastfetch.nixosModules.fastfetch ];

      programs.fastfetch = {
        logo = lib.mkDefault "Nebula.png";
        package = config.programs.fastfetch.finalPackage;
      };
    };
}
