{ inputs, withSystem, ... }:

{
  flake.nixosConfigurations = {
    ####  yoda  ################################################################
    "yoda" = withSystem "x86_64-linux" (ctx@{config, inputs', pkgs, ...}:

      inputs.nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; packages = config.packages; };

        modules = [
          ./yoda
          ../nixos

          inputs.home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "home-manager-backup";
              users.k = import ./yoda/home-manager.nix {
                inherit pkgs;
              };
              extraSpecialArgs = {
                inherit inputs;
              };
            };
          }
        ];
      }
    );
    ####  nix  #################################################################
    "nix" = withSystem "aarch64-linux" (ctx@{ config, inputs', ...}:
      inputs.nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; packages = config.packages; };
        modules = [
          ./nix
          ../nixos
        ];
      }
    );
  };
}

