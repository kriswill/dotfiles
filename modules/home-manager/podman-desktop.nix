{
  flake.modules.homeManager.podman-desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.kriswill.podman-desktop.enable = lib.mkEnableOption "Podman Desktop";
      config = lib.mkIf config.kriswill.podman-desktop.enable {
        home.packages = [
          pkgs.podman-desktop
          pkgs.podman
          # vfkit is the helper binary podman drives for the "applehv" machine
          # provider (see config/containers/containers.conf). Pin it explicitly so a
          # nixpkgs bump can't drop it off PATH and break `podman machine start`.
          pkgs.vfkit
          pkgs.k9s
        ];

        xdg.configFile."containers/containers.conf".source = config.lib.file.mkOutOfStoreSymlink (
          config.home.homeDirectory + "/src/dotfiles/config/containers/containers.conf"
        );

        xdg.dataFile."containers/podman-desktop/configuration/settings.json".source =
          config.lib.file.mkOutOfStoreSymlink
            (config.home.homeDirectory + "/src/dotfiles/config/containers/podman-desktop-settings.json");
      };
    };
}
