{
  flake.modules.homeManager.podman-desktop =
    {
      config,
      lib,
      ...
    }:
    {
      options.kriswill.podman-desktop.enable = lib.mkEnableOption "Podman Desktop";
      config = lib.mkIf config.kriswill.podman-desktop.enable {
        # podman-desktop / podman / vfkit / k9s moved to the nix-darwin per-user
        # profile, gated on this toggle — see modules/darwin/user-packages.nix.
        # (vfkit is the helper podman drives for the "applehv" machine provider;
        # it's pinned explicitly there so a nixpkgs bump can't break
        # `podman machine start`.)
        xdg.configFile."containers/containers.conf".source = config.lib.file.mkOutOfStoreSymlink (
          config.home.homeDirectory + "/src/dotfiles/config/containers/containers.conf"
        );

        xdg.dataFile."containers/podman-desktop/configuration/settings.json".source =
          config.lib.file.mkOutOfStoreSymlink
            (config.home.homeDirectory + "/src/dotfiles/config/containers/podman-desktop-settings.json");
      };
    };
}
