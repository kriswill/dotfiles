{
  description = "Kris's NixOS Flake";

  inputs = {
    nix-formatter-pack = {
      url = "github:Gerschtli/nix-formatter-pack";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nurpkgs.url = "github:nix-community/NUR";
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
      flake-inputs = inputs;
      forEachSystem = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      formatterPackArgsFor = forEachSystem (system: {
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
      nixosConfigurations = import ./machines {
        inherit flake-inputs rootPath;
      };

      checks = forEachSystem (system: {
        nix-formatter-pack-check = nix-formatter-pack.lib.mkCheck formatterPackArgsFor.${system};
      });

      formatter = forEachSystem (system: nix-formatter-pack.lib.mkFormatter formatterPackArgsFor.${system});
    };
}
