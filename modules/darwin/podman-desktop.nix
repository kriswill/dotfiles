# Kris' Podman Desktop (system-level port of the old home-manager module).
#
# nix-darwin has no programs.podman-desktop, so the config — containers.conf and
# Podman Desktop's settings.json — lives in the stow tree (home/podman-desktop)
# and is symlinked into ~ by dotfiles-stow.nix. That's the same live-editable
# behaviour the old `config.lib.file.mkOutOfStoreSymlink` gave (symlink straight
# into the repo). settings.json is rewritten by the GUI app at runtime; the
# normalize-podman-settings git filter (see .gitattributes) scrubs the volatile
# fields on commit. The podman-desktop / podman / vfkit / k9s packages are
# declared per-host in users.users.k.packages (modules/hosts/*.nix); this module
# only carries the enable toggle.
{
  flake.modules.darwin.podman-desktop =
    {
      lib,
      config,
      ...
    }:
    {
      options.kriswill.podman-desktop.enable = lib.mkEnableOption "Podman Desktop";
      config = lib.mkIf config.kriswill.podman-desktop.enable {
        # Expose /libexec in the system + per-user profiles (default pathsToLink
        # is bin/share/info only; this list-merges). podman's bundled machine
        # helpers live at $out/libexec/podman/{vfkit,gvproxy} (pkgs/podman.nix),
        # and podman's default helper search is "$BINDIR/../libexec/podman".
        # When podman runs via the profile symlink, $BINDIR is the profile bin,
        # so the helpers are only discoverable if the profile links libexec.
        environment.pathsToLink = [ "/libexec" ];
      };
    };
}
