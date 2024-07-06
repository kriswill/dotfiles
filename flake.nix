{
  description = "Kris's NixOS Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-formatter-pack = {
      url = "github:Gerschtli/nix-formatter-pack";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nur.url = "github:nix-community/nur";
  };

  outputs =
    inputs @ { self
    , nixpkgs
      # , home-manager
    , nix-formatter-pack
    , ...
    }:
    let
      rootPath = self;
      inherit (self) outputs;
      inherit (nixpkgs.lib) genAttrs;
      systems = genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      formatterPackArgsFor = systems (system: {
        inherit nixpkgs system;
        checkFiles = [ rootPath ];

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

      nixosConfigurations = import ./machines {
        inherit inputs rootPath outputs;
      };

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
