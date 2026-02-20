{
  lib,
  config,
  ...
}:
{
  options.kriswill.karabiner.enable = lib.mkEnableOption "Kris' Karabiner Elements";
  config = lib.mkIf config.kriswill.karabiner.enable (
    let
      configDir = config.home.homeDirectory + "/src/dotfiles/config/karabiner";
      ln = config.lib.file.mkOutOfStoreSymlink;
    in
    {
      xdg.configFile = {
        "karabiner/karabiner.json".source = ln (configDir + "/karabiner.json");
      };
    }
  );
}
