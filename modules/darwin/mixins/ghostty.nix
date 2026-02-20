{ lib, config, ... }:
{
  options.kriswill.ghostty.enable = lib.mkEnableOption "Ghostty terminal";
  config = lib.mkIf config.kriswill.ghostty.enable {
    homebrew.casks = [ "ghostty" ];
  };
}
