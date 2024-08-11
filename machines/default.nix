{ inputs, withSystem, ... }:

let
  nixosSystem =
    system: args:
    withSystem system (
      { self', ... }:
      inputs.nixpkgs.lib.nixosSystem (
        {
          specialArgs = {
            inherit inputs;
            inherit (self') packages;
          };
        }
        // args
      )
    );
in
{
  flake = {
    nixosConfigurations = {
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

    homeConfigurations = {
      ####  k  ###################################################################
      "k@yoda" = withSystem "x86_64-linux" (
        { pkgs, ... }:
        inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit inputs;
          };
          modules = [ ./yoda/home-manager.nix ];
        }
      );
    };
  };
}
