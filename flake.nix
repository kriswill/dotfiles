{
  description = "Kris' NixOS Flake";

  nixConfig = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      # Replace the official cache with a mirror located in China
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
    ];

    extra-substituters = [
      # Nix community's cache server
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = 
    { self, 
      nixpkgs, 
      home-manager,
      flake-utils,
      ...
    } @ inputs:
    let
      inherit (flake-utils.lib) eachDefaultSystem;
      inherit (nixpkgs.lib) nixosSystem;
    in
    {
      nixosConfigurations = {
        yoda = nixpkgs.lib.nixosSystem {
          system = "x86_64-Linux";
          modules = [ ./machines/yoda/configuration.nix ];
          specialArgs = { inherit inputs; };
        };
      };
      nixosModules = import ./nixos;
      homeManagerModules = import ./home;
    }
    // eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      formatter = pkgs.nixpkgs-fmt;
      pakages = import ./pkgs { inherit pkgs; };
    });
}

            # make home-manager as a module of nixos
            # so that home-manager configuration will be deployed automatically when 
            # executing `nixos-rebuild switch`
            # home-manager.nixosModules.home-manager
            # {
            #   home-manager.useGlobalPkgs = true;
            #   home-manager.useUserPackages = true;
            #   home-manager.users.k = import ./home;

            #   # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
            # }