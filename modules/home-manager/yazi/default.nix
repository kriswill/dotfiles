{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.kriswill.yazi.enable = lib.mkEnableOption "yazi";
  config = lib.mkIf config.kriswill.yazi.enable {
    programs.yazi = {
      enable = lib.mkDefault true;
      shellWrapperName = "y";
      enableZshIntegration = true;
      plugins = with pkgs.yaziPlugins; {
        inherit git;
      };
      initLua = ''
        require("git"):setup()
      '';
      flavors = {
        kanagawa-dragon = pkgs.fetchFromGitHub {
          owner = "marcosvnmelo";
          repo = "kanagawa-dragon.yazi";
          rev = "49055274ff53772a13a8c092188e4f6d148d1694";
          hash = "sha256-gkzJytN0TVgz94xIY3K08JsOYG/ny63Oj2eyGWiWH4s=";
        };
      };
      theme = {
        flavor.dark = "kanagawa-dragon";
      };
      settings = {
        mgr.ratio = [
          1
          2
          3
        ];
      };
    };
  };
}
