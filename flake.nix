{
  description = "Kris's main flake";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-unstable-small";
    nix-config.url = "github:earthgman/nix-config";
    nix-config.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = flake-inputs@ { self, nix-config, ... }:
    let
      inherit (nix-config) lib;
      inputs = nix-config.inputs // flake-inputs;
    in
    {
      nixosConfigurations = import ./hosts { inherit inputs lib; };
    };
}
