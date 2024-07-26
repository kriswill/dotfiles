{ inputs, pkgs, ... }:
{
  programs.anyrun = {
    enable = true;
    config = {
      plugins = with inputs.anyrun.packages.${pkgs.system}; [
        applications
        randr
        shell
        rink
#         kidex
      ];
      width.absolute = 600;
      height.absolute = 0;
      y.fraction = 0.3;
      hidePluginInfo = true;
      closeOnClick = true;
      # x = { fraction = 0.5; };
      # y = { fraction = 0.3; };
      # width = { fraction = 0.3; };
      # hideIcons = false;
      # ignoreExclusiveZones = false;
      # layer = "overlay";
      # hidePluginInfo = false;
      # closeOnClick = false;
      # showResultsImmediately = false;
      # maxEntries = null;
    };
    extraCss = ''
     #window,
      #match,
      #entry,
      #plugin,
      #main {
        background: transparent;
      }

      #match:selected {
        background: @theme_selected_bg_color;
      }

      #match {
        padding: 3px;
        border-radius: 16px;
      }

      #entry, #plugin:hover {
        border-radius: 16px;
      }

      box#main {
        background: @theme_bg_color;
        border: 1px solid @theme_base_color;
        border-radius: 24px;
        padding: 8px;
      }
    '';

    # extraConfigFiles."some-plugin.ron".text = ''
    #   Config(
    #     // for any other plugin
    #     // this file will be put in ~/.config/anyrun/some-plugin.ron
    #     // refer to docs of xdg.configFile for available options
    #   )
    # '';
  };
}
