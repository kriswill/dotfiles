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
      # Symlink ghostty terminfo to ~/.terminfo so it's discoverable
      # before TERMINFO_DIRS is set (fixes SSH sessions where the
      # nix-darwin set-environment script runs before env vars are exported)
      home.file.".terminfo".source = ln "/Applications/Ghostty.app/Contents/Resources/terminfo";
    }
  );
}
