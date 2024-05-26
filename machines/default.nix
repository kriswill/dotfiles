{ inputs, rootPath, outputs, ... }:

let
  inherit (inputs) home-manager nixpkgs;
in
{
  ####  yoda  #################################################################

  "yoda" =
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit inputs system;
        config.allowUnfree = true;
      };
    in
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs outputs; };

      modules = [
        ./yoda
        ../nixos

        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.k = import ./yoda/home-manager.nix {
              inherit pkgs rootPath outputs;
            };
            extraSpecialArgs = {
              inherit inputs outputs;
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
    specialArgs = { inherit inputs outputs; };
  };
}
