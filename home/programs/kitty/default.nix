{
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font Mono";
      size = 16.0;
    };
    settings = {
      update_check_interval = 0;
      # fade | slant | separator | powerline | custom | hidden
      tab_bar_style = "powerline";
      # angled | slanted | round
      tab_powerline_style = "slanted";
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
  xdg.configFile."kitty/theme.conf".source = ./kanagawa.conf;
}
