{ nixpkgs, flake-inputs, rootPath, home-manager, ... }:

let
  pkgs = import nixpkgs {
    inherit flake-inputs;
    system = "x86_64-linux";
    config.allowUnfree = true;
  };

  ####  yoda  #################################################################

  username = "k";
  "yoda" = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit username;
      flake-inputs = flake-inputs;
    };
    modules = [
      ./yoda

      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users."${username}" = import ./yoda/home-manager.nix {
            inherit pkgs rootPath username;
          };
          extraSpecialArgs = {
            inherit username flake-inputs;
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
in
{
  inherit yoda nix;
}

