{
  lib,
  config,
  pkgs,
  ...
}:

{
  options.kriswill.brave.enable = lib.mkEnableOption "Kris' Brave config";
  config = lib.mkIf config.kriswill.brave.enable {
    programs.brave = {
      enable = true;
      package = pkgs.brave;
      extensions = [
        { id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa"; } # 1password
        { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # dark reader
      ];
    };
  };
}
