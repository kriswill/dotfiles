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
        config = {
          allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
            "claude-code"
          ];
        };
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
        aws-azure-login = pkgs.callPackage ./pkgs/aws-azure-login.nix { };
        claude-code = pkgs.callPackage ./pkgs/claude-code/package.nix { };
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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
