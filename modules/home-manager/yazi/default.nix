{
  flake.modules.homeManager.yazi =
    {
      lib,
      config,
      pkgs,
      inputs,
      ...
    }:
    let
      stateDir = "${config.xdg.stateHome}/yazi";
      # Default flavor for a fresh machine; the theme-switcher plugin overwrites
      # this file at runtime, and it's only seeded when absent (below), so a
      # rebuild never clobbers a saved selection. yazi picks the slot matching the
      # terminal's color mode at startup, so `light` is the light-terminal fallback.
      defaultThemeToml = pkgs.writeText "yazi-theme-default.toml" ''
        [flavor]
        dark = "kanagawa-kris"
        light = "kanagawa-lotus"
      '';
    in
    {
      options.kriswill.yazi.enable = lib.mkEnableOption "yazi";
      config = lib.mkIf config.kriswill.yazi.enable {
        # `magick` (ImageMagick 7) is required by the font previewer.
        home.packages = [ pkgs.imagemagick ];

        # theme.toml is intentionally NOT managed by programs.yazi (so it isn't a
        # read-only store symlink): point it at a writable file in yazi's state
        # dir that the theme-switcher plugin rewrites. yazi reads it at startup.
        xdg.configFile."yazi/theme.toml".source =
          config.lib.file.mkOutOfStoreSymlink "${stateDir}/theme.toml";

        # Seed the default selection once; preserve any runtime choice thereafter.
        home.activation.yaziThemeSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -p ${lib.escapeShellArg stateDir}
          if [ ! -e ${lib.escapeShellArg "${stateDir}/theme.toml"} ]; then
            run cp ${defaultThemeToml} ${lib.escapeShellArg "${stateDir}/theme.toml"}
            run chmod u+w ${lib.escapeShellArg "${stateDir}/theme.toml"}
          fi
        '';

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
            # Picks a Kanagawa flavor and writes it to the (writable) theme.toml
            # in yazi's state dir; bound to `T` below.
            theme-switcher = ./theme-switcher.yazi;
          };
          initLua = ''
            require("git"):setup()
          '';

          # All four flavors installed simultaneously (flavors/<name>.yazi). The
          # active one is selected by theme.toml's [flavor], which is NOT managed
          # here — see the writable out-of-store symlink + seed below — so the
          # theme-switcher plugin can persist a runtime choice.
          flavors = import ../../../pkgs/yazi-kanagawa-flavor/all.nix { inherit lib pkgs; };

          keymap.mgr.prepend_keymap = [
            {
              on = [ "T" ];
              run = "plugin theme-switcher";
              desc = "Switch Kanagawa flavor";
            }
          ];
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
