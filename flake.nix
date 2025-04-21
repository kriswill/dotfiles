{
  description = "Kris' Apple Nix Configuration";

  outputs =
    inputs@{
      self,
      nixpkgs,
      darwin,
      home-manager,
      ...
    }:
    let
      inherit (self) outputs;
      inherit (darwin.lib) darwinSystem;
      # All of my macs are Apple ARM
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
      lib = nixpkgs.lib.extend (
        _: _:
        import ./lib {
          lib = nixpkgs.lib;
          inherit inputs;
        }
      );
    in
    {
      inherit lib;
      darwinConfigurations = {
        "k" = darwinSystem {
          specialArgs = {
            inherit
              self
              inputs
              outputs
              lib
              ;
          };
          modules = [
            ./hosts/k
            home-manager.darwinModules.home-manager
            (lib.mkHomeManager ./home "k")
            { nixpkgs.hostPlatform = system; }
          ];
        };
        "SOC-Kris-Williams" = darwinSystem {
          specialArgs = {
            inherit
              self
              inputs
              outputs
              lib
              ;
          };
          modules = [
            ./hosts/SOC-Kris-Williams
            home-manager.darwinModules.home-manager
            (lib.mkHomeManager ./home "k")
            { nixpkgs.hostPlatform = system; }
          ];
        };
      };
      devShells.${system}.default = pkgs.mkShell {
        name = "dotfiles";
        packages = with pkgs; [
          deadnix
          statix
        ];
      };
      formatter.${system} = pkgs.nixfmt-tree;
      darwinModules = import ./modules/darwin { inherit lib; };
      darwinProfiles = {
        default = import ./profiles/darwin;
      };
    };

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.0.tar.gz";
    darwin = {
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/0.1.*.tar.gz";
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
