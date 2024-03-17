{
  description = "My Snowfall flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    
    snowfall-lib = {
      url = "github:snowfallorg/lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake = {
      url = "github:snowfallorg/flake";
      inputs.nixpkgs.follows = "unstable";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    let
      inherit (inputs) flake snowfall-lib;

      lib = snowfall-lib.mkLib {
        inherit inputs;
        package-namespace = "k";
        src = ./.;
      };
    in
    lib.mkFlake {
      channels-config.allowUnfree = true;
      overlays = [
        flake.overlays.default
      ];
    };
}
