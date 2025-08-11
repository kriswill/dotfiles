{
  description = "Kris' Apple Nix Configuration";

  outputs =
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      inherit (self) outputs;
      # All of my macs are Apple ARM
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
      lib = nixpkgs.lib.extend (
        _: _:
        import ./lib {
          inherit self inputs outputs;
        }
      );
    in
    {
      inherit lib;
      packages.${system} = {
        kitten = pkgs.callPackage ./pkgs/kitten.nix { };
        iv = pkgs.callPackage ./pkgs/iv.nix { };
      };
      darwinConfigurations = {
        k = lib.mkDarwin ./hosts/k "k";
        SOC-Kris-Williams = lib.mkDarwin ./hosts/SOC-Kris-Williams "k";
      };
      devShells.${system}.default = pkgs.mkShell {
        name = "dotfiles";
        packages = builtins.attrValues {
          inherit (pkgs)
            deadnix
            statix
            nixfmt-tree
            just
            ;
        };
        shellHook = ''
          PATH_add "$PWD/bin"
        '';
      };
      overlays = import ./overlays { inherit inputs; };
      formatter.${system} = pkgs.nixfmt-tree;
      darwinModules = rec {
        kriswill = import ./modules/darwin { inherit lib; };
        default = kriswill;
      };
      homeModules = rec {
        kriswill = import ./modules/home-manager { inherit lib; };
        default = kriswill;
      };
    };

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1.0.tar.gz";
    darwin = {
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/0.1.*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/0.1.*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
