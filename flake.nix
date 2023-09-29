{
  description = "Kris's NixOS Flake";

  inputs = {
    nix-formatter-pack = {
      url = "github:Gerschtli/nix-formatter-pack";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs @ { self
    , nixpkgs
    , home-manager
    , nix-formatter-pack
    , ...
    }:
    let
      rootPath = self;
      forEachSystem = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      formatterPackArgsFor = forEachSystem (system: {
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
      nixosConfigurations = import ./machines {
        inherit nixpkgs home-manager inputs rootPath;
      };

      checks = forEachSystem (system: {
        nix-formatter-pack-check = nix-formatter-pack.lib.mkCheck formatterPackArgsFor.${system};
      });

      formatter = forEachSystem (system: nix-formatter-pack.lib.mkFormatter formatterPackArgsFor.${system});
    };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
