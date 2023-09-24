{ nixpkgs, inputs, username, home-manager, ... }:

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
          users.${username} = import ../home/home.nix;
          extraSpecialArgs = {
            inherit inputs;
            inherit username;
          };
        };
      }
    ];
  };
}
