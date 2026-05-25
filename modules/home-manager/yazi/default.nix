{
  flake.modules.homeManager.yazi =
    {
      lib,
      config,
      pkgs,
      inputs,
      ...
    }:
    {
      options.kriswill.yazi.enable = lib.mkEnableOption "yazi";
      config = lib.mkIf config.kriswill.yazi.enable {
        programs.yazi = {
          enable = lib.mkDefault true;
          shellWrapperName = "y";
          enableZshIntegration = true;
          plugins = {
            inherit (pkgs.yaziPlugins) git;
            faster-piper = inputs.faster-piper-yazi;
          };
          initLua = ''
            require("git"):setup()
          '';

          flavors = {
            kanagawa-dragon = import ./_themes/kanagawa-dragon { inherit lib; };
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
            plugin = {
              prepend_fetchers = [
                {
                  group = "git";
                  url = "*";
                  run = "git";
                }
                {
                  group = "git";
                  url = "*/";
                  run = "git";
                }
              ];
              prepend_previewers = [
                {
                  url = "*.md";
                  run = ''faster-piper -- CLICOLOR_FORCE=1 glow -w=$w -s="${config.kriswill.glow.stylePath}" "$1"'';
                }
                {
                  url = "*.(py|sh|go|ts|css|yaml|yml|toml|html|conf|json|csv)";
                  run = "bat";
                }
              ];
            };
          };
        };
      };
    };
}
