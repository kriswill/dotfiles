{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;

    # package = pkgs.kitty;

    font = {
      name = "SauceCodePro Nerd Font";
      size = 14.0;
    };

    extraConfig = builtins.readFile ./kitty-theme/adwaita.conf;

    settings = {
      update_check_interval = 0;
      # fade | slant | separator | powerline | custom | hidden
      tab_bar_style = "powerline";
      # angled | slanted | round
      tab_powerline_style = "slanted";
      background_opacity = "0.9";
      confirm_os_window_close = 0;
      copy_on_select = "clipboard";
      enable_audio_bell = "no";
      hide_window_decorations = "yes";
      # linux_display_server = "wayland";
      placement_strategy = "bottom";
      scrollback_lines = 40000;
      # term = "xterm-256color";
      # visual_bell_duration = "0.1";
      # XDG_CURRENT_DESKTOP = "GNOME";
    };
    shellIntegration = {
      mode = "enabled";
      enableZshIntegration = true;
    };
  };
}
