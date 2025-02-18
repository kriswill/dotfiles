{
  description = "Kris' Nix Configuration";

  outputs =
    inputs @ { self
    , nixpkgs
    , nix-darwin
    , home-manager
    , ...
    }:
    let
      inherit (self) outputs;
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

      darwinConfigurations = {
        "k" = darwinSystem {
          specialArgs = {
            inherit self inputs outputs;
          };
          modules = [
            ./machines/k
            home-manager.darwinModules.home-manager
            (mkHomeManager ./home "k")
            {nixpkgs = {
               hostPlatform = "aarch64-darwin";
               # overlays = [ outputs.overlays.nixpkgs-unstable ];
             };}
          ];
        };
        "kwilliams1023" = darwinSystem {
          specialArgs = {
            inherit self inputs outputs;
          };
          modules = [
            ./machines/kwilliams1023
            home-manager.darwinModules.home-manager
            (mkHomeManager ./home "k")
            {nixpkgs = { hostPlatform = "aarch64-darwin"; };}
            {environment.systemPackages = [ inputs.fh.packages.aarch64-darwin.default ]; }
          ];
        };
      };
      darwinPackages = self.darwinConfigurations."k".pkgs;
      devShells.aarch64-darwin.default = self.darwinPackages.mkShell {
        name = "dotfiles";
        packages = with self.darwinPackages; [
          deadnix
          statix
        ];
      };
    };

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.0.tar.gz";
    nur.url = "github:nix-community/nur";
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*.tar.gz";
    fh.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    mac-app-util.url = "github:hraban/mac-app-util";
    home-manager.url = "https://flakehub.com/f/nix-community/home-manager/*.tar.gz";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # NOT working on aarch64-darwin - using homebrew for now
    # ghostty.url = "github:ghostty-org/ghostty";
    fenix.url = "https://flakehub.com/f/nix-community/fenix/0.1.2156.tar.gz";
  };
}
