{ flake-inputs, pkgs, nixpkgs, ... }:

{
  nix = {
    package = pkgs.nixFlakes;

    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      substituters = [
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    gc = {
      automatic = true;
    };
    nixPath = [ "nixpkgs=${flake-inputs.nixpkgs}" ];
    registry.nixpkgs = {
      from = {
        id = "nixpkgs";
        type = "indirect";
      };
      flake = flake-inputs.nixpkgs;
    };
  };

  nixpkgs = {
    overlays = [
      flake-inputs.nurpkgs.overlay
    ];
    # Allow unfree packages
    config = {
      allowUnfree = true;
      allowUnsupportedSystem = true;
    };
  };
}
