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
        # `magick` (ImageMagick 7) is required by the font previewer.
        home.packages = [ pkgs.imagemagick ];

        programs.yazi = {
          enable = lib.mkDefault true;
          shellWrapperName = "y";
          enableZshIntegration = true;
          plugins = {
            inherit (pkgs.yaziPlugins) git;
            faster-piper = inputs.faster-piper-yazi;
            # LuaCATS type stubs for the yazi Lua API (ya, rt, fs, Command,
            # Err, …). Pure `---@meta` annotations; never referenced by a
            # previewer/preloader/fetcher, so yazi never executes it. Lands at
            # ~/.config/yazi/plugins/types.yazi for lua_ls (.luarc.json there).
            types = inputs.yazi-plugins + "/types.yazi";
            # Font previewer with light glyphs on a transparent background.
            # Wired via explicit preloader + previewer rules below — yazi
            # won't let a user plugin named `font` override the preset.
            font-dark = ./font-dark.yazi;
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
              # Font previews are rendered by the *preloader* (it writes the
              # cached image) and merely displayed by the previewer. Override
              # both, else the built-in `font` preloader caches a white image
              # first and `font-dark`'s peek short-circuits on the existing
              # cache. Mirror the preset's two font mime rules.
              prepend_preloaders = [
                {
                  mime = "font/*";
                  run = "font-dark";
                }
                {
                  mime = "application/ms-opentype";
                  run = "font-dark";
                }
              ];
              prepend_previewers = [
                {
                  mime = "font/*";
                  run = "font-dark";
                }
                {
                  mime = "application/ms-opentype";
                  run = "font-dark";
                }
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
