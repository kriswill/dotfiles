{ nixpkgs, flake-inputs, rootPath, home-manager, ... }:

let
  pkgs = import nixpkgs {
    inherit flake-inputs;
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
{
  ####  yoda  #################################################################

  "yoda" = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs.flake-inputs = flake-inputs;

    modules = [
      ./yoda

      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.k = import ./yoda/home-manager.nix {
            inherit pkgs rootPath;
          };
          extraSpecialArgs = {
            inherit flake-inputs;
          };
        };
      }
    ];
  };

  ####  nix  ##################################################################

  "nix" = nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      ./nix
      ../nixos
    ];
    specialArgs.flake-inputs = flake-inputs;
  };
}
