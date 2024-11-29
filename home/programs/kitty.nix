{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    font = {
      name = "SauceCodePro Nerd Font";
      size = 18;
    };
    shellIntegration.enableZshIntegration = true;

    extraConfig = builtins.readFile ./kitty-theme/adwaita.conf;

    settings = {
      background_opacity = "0.9";
      confirm_os_window_close = 0;
      copy_on_select = "clipboard";
      enable_audio_bell = "no";
      hide_window_decorations = "yes";
      # linux_display_server = "wayland";
      placement_strategy = "center";
      scrollback_lines = 20000;
      term = "xterm-256color";
      visual_bell_duration = "0.1";
      # XDG_CURRENT_DESKTOP = "GNOME";
    };
  };
}
