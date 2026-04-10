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
      pkgs = import nixpkgs {
        inherit system;
      };
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
        mini = lib.mkDarwin ./hosts/mini "k";
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
        kriswill = import ./modules/darwin {
          inherit lib;
        };
        default = kriswill;
      };
      homeModules = rec {
        kriswill = ./modules/home-manager;
        default = kriswill;
      };
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
