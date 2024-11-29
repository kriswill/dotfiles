{
  description = "Kris' Nix Configuration";

  outputs =
    inputs @ { self
    , nixpkgs
    , determinate
    # , systems
    , nix-darwin
    , home-manager
    # , nix-formatter-pack
    , ...
    }:
    let
      # inherit (self) outputs lib;
      # inherit (lib) genAttrs;
      inherit (nix-darwin.lib) darwinSystem;

      # This defines the home-manager config module
      mkHomeManager = path: username: {
        home-manager = {
          useUserPackages = true;
          useGlobalPkgs = true;
          users."${username}" = path;
          sharedModules = [
            inputs.mac-app-util.homeManagerModules.default
           ];
          extraSpecialArgs = {
            inherit inputs username;
          };
        };
      };
    in
    {
      lib = builtins.foldl' (lib: overlay: lib.extend overlay) nixpkgs.lib [
        (import ./lib)
      ];
      # Custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };

      nixosConfigurations = import ./machines {
        inherit inputs outputs;
      };

      #> darwin-rebuild build --flake .#k
      darwinConfigurations = {
        "k" = darwinSystem {
          specialArgs = {
            inherit self inputs outputs;
          };
          modules = [
            ./machines/k
            determinate.darwinModules.default
            home-manager.darwinModules.home-manager
            (mkHomeManager ./home "k")
            {nixpkgs = {
               hostPlatform = "aarch64-darwin";
               # overlays = [ outputs.overlays.nixpkgs-unstable ];
             };}
          ];
        };
      };
      darwinPackages = self.darwinConfigurations."k".pkgs;
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";
    # systems.url = "github:nix-systems/default";
    nur.url = "github:nix-community/nur";
    # nix-formatter-pack.url = "github:Gerschtli/nix-formatter-pack";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";
    nix-darwin.url = "github:LnL7/nix-darwin";
    mac-app-util.url = "github:hraban/mac-app-util";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    fenix.url = "github:nix-community/fenix";
  };
}
