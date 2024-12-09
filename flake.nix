{
  description = "Kris's main flake";

  inputs = {
    nix-config.url = "github:earthgman/nix-config";
  };

  outputs = flake-inputs@ { self, nix-config, ... }:
    let
      inherit (nix-config) lib;
      inputs = flake-inputs // nix-config.inputs;
    in
    {
      nixosConfigurations = import ./hosts { inherit inputs lib; };
    };
}
