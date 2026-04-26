# Materialises GUI apps from home.packages as real .app bundle directories
# at ~/Applications/Home Manager Apps/ via home-manager's targets.darwin.copyApps.
#
# Symlinks pointing into /nix/store are not reliably enumerated by macOS
# bundle scanners (Spotlight, mdimport, third-party automation harnesses).
# copyApps rsyncs the buildEnv /Applications tree with --copy-unsafe-links
# so each .app becomes a real directory tree at a path Spotlight indexes.
#
# Default for home.stateVersion >= "25.11"; we pin "24.11" in lib/default.nix,
# so opt in explicitly.
#
# Disk cost: real copies, not store-shared (~hundreds of MB across the
# current GUI app set). macOS 26.3 has a known signature-verification
# regression with mtime=1 that home-manager works around; we are on 25.x.
{
  lib,
  config,
  ...
}:
let
  cfg = config.kriswill.copyApps;
in
{
  options.kriswill.copyApps.enable = lib.mkEnableOption "copy nix GUI apps into ~/Applications/Home Manager Apps/";

  config = lib.mkIf cfg.enable {
    targets.darwin.linkApps.enable = false;
    targets.darwin.copyApps.enable = true;

    # Transitional cleanup: the previous mkalias-symlinks attempt left bare
    # symlinks at ~/Applications/<App>.app and a manifest at
    # $XDG_STATE_HOME/home-manager-app-bundles.list. After one successful
    # activation per host, this block can be deleted — without the manifest,
    # it is a no-op anyway.
    home.activation.cleanupLegacyAppBundleSymlinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      manifest="''${XDG_STATE_HOME:-$HOME/.local/state}/home-manager-app-bundles.list"
      if [ -f "$manifest" ]; then
        while IFS= read -r app_name; do
          target="$HOME/Applications/$app_name"
          if [ -L "$target" ] && readlink "$target" | grep -q '^/nix/store/'; then
            rm -f "$target"
          fi
        done < "$manifest"
        rm -f "$manifest"
      fi
    '';
  };
}
