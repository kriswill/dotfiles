# Creates macOS Finder aliases for GUI apps installed via home.packages,
# making them visible to Spotlight (Cmd+Space) and Launchpad.
#
# Nix store symlinks are invisible to Spotlight. Home-manager's built-in
# linkapps.nix (targets.darwin.linkApps) also creates symlinks, so it has
# the same problem. This module disables linkapps and instead uses mkalias
# to create real Finder aliases that Spotlight indexes.
#
# We can't use config.home.profileDirectory because with useUserPackages=true
# the profile path (/etc/profiles/per-user/$USER) has no Applications/ dir.
# Instead, pkgs.buildEnv collects .app bundles directly from home.packages.
#
# The aliases are recreated from scratch on every activation. They point into
# the nix store, so they break if the store path is garbage-collected before
# the next rebuild.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.kriswill.mkalias;
  appsEnv = pkgs.buildEnv {
    name = "home-manager-applications";
    paths = config.home.packages;
    pathsToLink = [ "/Applications" ];
  };
in
{
  options.kriswill.mkalias.enable = lib.mkEnableOption "macOS Finder aliases for GUI apps";

  config = lib.mkIf cfg.enable {
    targets.darwin.linkApps.enable = false;

    home.activation.aliasApplications = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      app_folder="$HOME/Applications/Home Manager Apps"
      rm -rf "$app_folder"
      mkdir -p "$app_folder"

      find "${appsEnv}/Applications" -maxdepth 1 -name "*.app" -type l 2>/dev/null | while read -r src; do
        app_name=$(basename "$src")
        real_src=$(readlink "$src")
        ${pkgs.mkalias}/bin/mkalias "$real_src" "$app_folder/$app_name"
      done
    '';
  };
}
