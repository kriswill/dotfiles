{ nixpkgs, inputs, rootPath, home-manager, ... }:

let
  pkgs = import nixpkgs {
    inherit inputs;
    system = "x86_64-linux";
    config.allowUnfree = true;
  };

  ####  yoda  #################################################################

  username = "k";
  "yoda" = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs username;
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
            inherit inputs username;
          };
        };
      }
    ];
  };
  in let

  ####  potato  ###############################################################

  username = "g";

  "potato" = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs username;
    };
    modules = [
      ./potato

      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users."${username}" = import ./potato/home-manager.nix {
            inherit pkgs rootPath username;
          };
          extraSpecialArgs = {
            inherit inputs username;
          };
        };
      }
    ];
  };
  in let

  ####  nix  ##################################################################

  "nix" = nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = [
      ./nix
    ];
  };
in
{
  inherit yoda potato nix;
}

