{ inputs, pkgs, nixpkgs, ... }:

{
  nix = {
    package = pkgs.unstable.nixVersions.latest;

    settings = {
      trusted-users = [ "root" "@wheel" ];
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
      system-features = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      substituters = [ "https://nix-community.cachix.org" ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    # set by nh.clean.enable
    # gc = {
    #   automatic = true;
    # };
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
      (final: prev: {
        unstable = import inputs.nixpkgs-unstable {
          inherit (final) system;
          config.allowUnfree = true;
        };
        trunk = import inputs.nixpkgs-trunk {
          inherit (final) system;
          config.allowUnfree = true;
        };
        wallpapers = import ../packages/shared/wallpapers.nix;
        xdg-desktop-portal-gtk = (prev.xdg-desktop-portal-gtk.overrideAttrs {
          postInstall = ''
            sed -i 's/UseIn=gnome/UseIn=gnome;Hyprland;none+i3/' $out/share/xdg-desktop-portal/portals/gtk.portal
          '';
        }).override {
          # prevent collision with Gnome when installing alongside Hyprland
          buildPortalsInGnome = false;
        };
      })
    ];
    # Allow unfree packages
    config = {
      allowUnfree = true;
      allowUnsupportedSystem = true;
    };
  };
}
