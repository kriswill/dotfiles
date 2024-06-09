{
  description = "Kris' Nix Configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/nur";
    nix-formatter-pack = {
      url = "github:Gerschtli/nix-formatter-pack";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland = {
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs @ { self
    , nixpkgs
    , nixpkgs-unstable
    , nix-darwin
    , home-manager
    , nix-formatter-pack
    , ...
    }:
    let
      inherit (self) outputs;
      inherit (nixpkgs.lib) genAttrs;
      inherit (nix-darwin.lib) darwinSystem;
      systems = genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      # This defines the home-manager config module
      mkHomeManager = path: username: {
        home-manager = {
          useUserPackages = true;
          useGlobalPkgs = true;
          users."${username}" = path;
          sharedModules = [ ];
          extraSpecialArgs = {
            inherit inputs username;
          };
        };
      };
      formatterPackArgsFor = systems (system: {
        inherit nixpkgs system;
        checkFiles = [ self ];

        config.tools = {
          deadnix = {
            enable = true;
            noLambdaPatternNames = true;
          };
          nixpkgs-fmt.enable = true;
          statix.enable = true;
        };
      });
    in
    {
      # Custom packages and modifications, exported as overlays
      overlays = import ./overlays { inherit inputs; };
      rootPath = self;

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
            home-manager.darwinModules.home-manager
            (mkHomeManager ./home "k")
            {nixpkgs = {
              hostPlatform = "aarch64-darwin";
              overlays = [ outputs.overlays.nixpkgs-unstable ];
            };}
            # {
            #   _module.args = { inherit inputs outputs; };
            #   nixpkgs = import inputs.nixpkgs {
            #     system = "aarch64-darwin";
            #     overlays = [
            #       inputs.nur.overlay
            #       outputs.overlays.nixpkgs-unstable
            #     ];
            #   };
            #   useGlobalPkgs = true;
            #   useUserPackages = true;
            #   home-manager = {
            #     users.k = import ./home;
            #   };
            #   users.users.k.home = "/Users/k";
            # }
          ];
        };
      };
      darwinPackages = self.darwinConfigurations."k".pkgs;

      checks = systems (system: {
        nix-formatter-pack-check = nix-formatter-pack.lib.mkCheck formatterPackArgsFor.${system};
      });

      formatter = systems (system: nix-formatter-pack.lib.mkFormatter formatterPackArgsFor.${system});

      devShells = systems (system: {
        "${system}.default" = nixpkgs.legacyPackages.${system}.mkShell {
          shellHook = ''
            echo "HI!"
          '';
        };
      });
    };
}
