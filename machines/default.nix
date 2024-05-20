{ inputs, rootPath, ... }:

let
  inherit (inputs) home-manager nixpkgs;
  pkgs = import nixpkgs {
    inherit inputs;
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
{
  ####  yoda  #################################################################

  "yoda" = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };

    modules = [
      ./yoda
      ../nixos

      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.k = import ./yoda/home-manager.nix {
            inherit pkgs rootPath;
          };
          extraSpecialArgs = {
            inherit inputs;
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
    specialArgs = { inherit inputs; };
  };
}
