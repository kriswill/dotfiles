{ inputs, outputs, pkgs, nixpkgs, ... }:

{
  nix = {
    package = pkgs.nixFlakes;

    settings = {
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      system-features = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
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
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    registry.nixpkgs = {
      from = {
        id = "nixpkgs";
        type = "indirect";
      };
      flake = inputs.nixpkgs;
    };
  };

  nixpkgs = {
    overlays = [
      inputs.nur.overlay
      outputs.overlays.unstable-packages
    ];
    config = {
      # Allow unfree packages
      allowUnfree = true;
      allowUnsupportedSystem = true;
    };
  };
}
