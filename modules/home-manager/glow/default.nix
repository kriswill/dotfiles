{
  flake.modules.homeManager.glow =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      cfg = config.kriswill.glow;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.modules) mkIf;
      stylePath = "${config.home.homeDirectory}/Library/Preferences/glow/kanagawa-dragon.json";
    in
    {
      options.kriswill.glow = {
        enable = mkEnableOption "glow";
        stylePath = mkOption {
          type = lib.types.str;
          readOnly = true;
          default = stylePath;
          description = "Absolute path to the glow style JSON, for other modules to reference.";
        };
      };
      config = mkIf cfg.enable {
        home.packages = with pkgs; [ glow ];

        home.file = {
          "Library/Preferences/glow/kanagawa-dragon.json".source = ./kanagawa-dragon.json;
          "Library/Preferences/glow/glow.yml".text = ''
            ${builtins.readFile ./glow.yml}
            style: "${stylePath}"
          '';
        };
      };
    };
}
