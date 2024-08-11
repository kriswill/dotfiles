{
  description = "Kris's main flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-trunk.url = "github:NixOS/nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";
    # ditching nixvim, going to repave this...
    # nixvim.url = "github:kriswill/nixvim";
    nixvim.url = "git+file:/home/k/src/nixvim?shallow=1";
    nixvim.inputs.nixpkgs.follows = "nixpkgs-unstable";
    nur.url = "github:nix-community/nur";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-unstable";
    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs-unstable";
    grub2-themes.url = "github:vinceliuice/grub2-themes";
    gBar.url = "github:scorpion-26/gBar";
    gBar.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (top: {
      systems = [ "x86_64-linux" ];
      imports = [
        ./machines
        ./devShells.nix
        ./pre-commit-hooks.nix
        ./packages
      ];

      perSystem =
        { config, system, ... }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            localSystem = system;
            overlays = [ self.overlays.default ];
            config = {
              allowUnfree = true;
              allowAliases = true;
            };
          };

          formatter = config.treefmt.build.wrapper;
        };

      flake = {
        overlays = import ./overlays top;
      };
    });
}
