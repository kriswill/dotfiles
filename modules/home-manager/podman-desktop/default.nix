{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.kriswill.podman-desktop.enable = lib.mkEnableOption "Podman Desktop";
  config = lib.mkIf config.kriswill.podman-desktop.enable {
    home.packages = [ pkgs.podman-desktop ];

    xdg.configFile."containers/containers.conf".source = config.lib.file.mkOutOfStoreSymlink (
      config.home.homeDirectory + "/src/dotfiles/config/containers/containers.conf"
    );

    xdg.dataFile."containers/podman-desktop/configuration/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink
        (config.home.homeDirectory + "/src/dotfiles/config/containers/podman-desktop-settings.json");
  };
}
