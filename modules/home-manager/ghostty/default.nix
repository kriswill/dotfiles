{
  lib,
  config,
  ...
}:
{
  options.kriswill.ghostty.enable = lib.mkEnableOption "Kris' Ghostty";
  config = lib.mkIf config.kriswill.ghostty.enable (
    let
      configDir = config.home.homeDirectory + "/src/dotfiles/config/ghostty";
      ln = config.lib.file.mkOutOfStoreSymlink;
    in
    {
      xdg.configFile = {
        "ghostty/config".source = ln configDir + "/config";
      };
    }
  );
}
