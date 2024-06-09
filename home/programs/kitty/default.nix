{ pkgs, ... }:
{
  programs.kitty = {
    enable = true;
    font = {
      name = "SauceCodePro Nerd Font Mono";
      size = 18.0;
    };
    settings = {
      placement_strategy = "top-left";
      window_margin_width = "0";
      window_padding_width = "5";
      hide_window_decorations = "titlebar-only";
      cursor_blink_interval = 0;
      macos_show_window_title_in = "none";
    };
    shellIntegration = {
      mode = "enabled";
      enableZshIntegration = true;
    };
    extraConfig = ''
      include theme.conf
    '';
  };
  #xdg.configFile."kitty/theme.conf".source = ./catppuccin-mocha.conf;
  xdg.configFile."kitty/theme.conf".source = ./kanagawa.conf;
}
