{
  description = "Kris' Nix Configuration";

  outputs = inputs@{ self, nixpkgs, darwin, home-manager, ... }:
    let
      inherit (self) outputs;
      inherit (darwin.lib) darwinSystem;

      # This defines the home-manager config module
      mkHomeManager = path: username: {
        home-manager = {
          useUserPackages = true;
          useGlobalPkgs = true;
          users."${username}" = path;
          sharedModules = [ inputs.mac-app-util.homeManagerModules.default ];
          extraSpecialArgs = { inherit inputs username; };
        };
      };
    in {
      lib = builtins.foldl' (lib: overlay: lib.extend overlay) nixpkgs.lib
        [ (import ./lib) ];
      # Custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };

      darwinConfigurations = {
        "k" = darwinSystem {
          specialArgs = { inherit self inputs outputs; };
          modules = [
            ./machines/k
            home-manager.darwinModules.home-manager
            (mkHomeManager ./home "k")
            {
              nixpkgs = {
                hostPlatform = "aarch64-darwin";
                # overlays = [ outputs.overlays.nixpkgs-unstable ];
              };
            }
          ];
        };
        "SOC-Kris-Williams" = darwinSystem {
          specialArgs = { inherit self inputs outputs; };
          modules = [
            ./machines/SOC-Kris-Williams
            home-manager.darwinModules.home-manager
            (mkHomeManager ./home "k")
            { nixpkgs = { hostPlatform = "aarch64-darwin"; }; }
            {
              environment.systemPackages =
                [ inputs.fh.packages.aarch64-darwin.default ];
            }
          ];
        };
      };
      darwinPackages = self.darwinConfigurations."k".pkgs;
      devShells.aarch64-darwin.default = self.darwinPackages.mkShell {
        name = "dotfiles";
        packages = with self.darwinPackages; [ deadnix statix ];
      };
    };

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.0.tar.gz";
    nur = {
      url = "github:nix-community/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fh = {
      url = "https://flakehub.com/f/DeterminateSystems/fh/*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    minimal-tmux = {
      url = "github:niksingh710/minimal-tmux-status";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
