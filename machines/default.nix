{ nixpkgs, inputs, username, rootPath, home-manager, ... }:

let
  pkgs = import nixpkgs {
    inherit inputs;
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
{
  "yoda" = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      inherit username;
    };
    modules = [
      ./yoda

      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.${username} = import ./yoda/home-manager.nix {
            inherit pkgs rootPath username;
          };
          extraSpecialArgs = {
            inherit inputs;
            inherit username;
          };
        };
      }
    ];
  };
}
