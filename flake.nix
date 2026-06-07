{
  description = "my NixOS configurations";

  inputs = {
    snowglobe-lib = {
      url = "git+https://codeberg.org/earthgman/snowglobe-lib";
      # Be sure to also uncomment this if you use your own nixpkgs input to avoid duplicate nixpkgs repos in the store.
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs.follows = "snowglobe-lib/nixpkgs";
    # comment above and uncomment below to pin your own nixpkgs revision in the flake.lock.
    # Could cause instabilities, use at your own risk.
    # nixpkgs = {
    #   url = "github:NixOS/nixpkgs/nixos-unstable";
    # };

    import-tree.follows = "snowglobe-lib/import-tree";
  };

  outputs =
    {
      self,
      nixpkgs,
      snowglobe-lib,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;
      outputs = self.outputs;
      import-tree = inputs.import-tree;
    in
    {
      # expose hosts configured under this flake
      nixosConfigurations = import ./nixosConfigurations { inherit lib inputs outputs; };

      # expose your custom modules.
      nixosModules.default = import-tree [
        ./nixosModules/default
        # apply your nixpkgs overlays
        { nixpkgs.overlays = builtins.attrValues outputs.overlays; }
      ];

      # expose your overlays
      overlays = import ./overlays { inherit inputs; };

      # your custom derivations
      packages =
        let
          supported-systems = [
            # add more system targets if you need.
            "x86_64-linux"
          ];
        in
        # generate a package attribute set for each supported architecture
        lib.genAttrs supported-systems (
          system:
          import ./packages {
            pkgs = import nixpkgs {
              config.allowUnfree = true;
              inherit system;
              # give your packages access to your overlays
              overlays = builtins.attrValues outputs.overlays; # transform the set of overlays to a list
            };
          }
        );
    };
}
