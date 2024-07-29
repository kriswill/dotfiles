{ pkgs, lib, ... }:

with pkgs.unstable; {

  programs.yazi = {
    enable = true;
    package = yazi;
    enableZshIntegration = true; # adds function "ya"
    settings = import ./settings.nix { inherit lib; pkgs = pkgs.unstable; };
  };

  # xdg.configFile = {
  #   "yazi" = {
  #     source = lib.cleanSourceWith {
  #       filter =
  #         name: _type:
  #         let
  #           baseName = baseNameOf (toString name);
  #         in
  #         !lib.hasSuffix ".nix" baseName;
  #       src = lib.cleanSource ./configs/.;
  #     };
  #
  #     recursive = true;
  #   };
  # };
}
