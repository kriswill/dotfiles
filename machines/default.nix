{ inputs, withSystem, ... }:

let
  nixosSystem =
    system: args:
    withSystem system (
      ctx@{
        config,
        inputs',
        pkgs,
        ...
      }:
      inputs.nixpkgs.lib.nixosSystem (
        {
          specialArgs = {
            inherit inputs;
            inherit (config) packages;
          };
        }
        // args
      )
    );
in
{
  flake.nixosConfigurations = {
    ####  yoda  ################################################################
    "yoda" = nixosSystem "x86_64-linux" {
      modules = [
        ./yoda
        ../nixos
      ];
    };

    ####  nix  #################################################################
    "nix" = nixosSystem "aarch64-linux" {
      modules = [
        ./nix
        ../nixos
      ];
    };
  };

  flake.homeConfigurations = {
    ####  k  ###################################################################
    "k@yoda" = withSystem "x86_64-linux" (
      {
        config,
        inputs',
        pkgs,
        ...
      }:
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs;
        };
        modules = [
          ./yoda/home-manager.nix
        ];
      }
    );
  };
}
