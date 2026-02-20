{ lib, config, ... }:
{
  options.kriswill.ghostty.enable = lib.mkEnableOption "Ghostty terminal";
  config = lib.mkIf config.kriswill.ghostty.enable {
    homebrew.casks = [ "ghostty" ];
    environment.variables.TERMINFO_DIRS = [
      "/Applications/Ghostty.app/Contents/Resources/terminfo"
      "/usr/share/terminfo"
    ];
  };
}
