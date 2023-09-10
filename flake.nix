{
  description = "Kris's NixOS Flake";

  nixConfig = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      # Nix community's cache server
      "https://nix-community.cachix.org"
      "https://cache.nixos.org/"
    ];

    extra-substituters = [];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }@inputs:
  let
    username = "k";
  in
  {
    nixosConfigurations = {
      "yoda" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          inherit username;
        };
        modules = [
          ./machines/yoda/configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = import ./home/home.nix;
            home-manager.extraSpecialArgs = {
              inherit inputs;
              inherit username;
            };
          }
        ];
      };
    };
  };
}