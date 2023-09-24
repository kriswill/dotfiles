{ pkgs, specialArgs, ... }:

let
  fontSize = 13;
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";
      bell = {
        animation = "EaseOutExpo";
        duration = 5;
        color = "#efefef";
      };
      colors = {
        primary = {
          background = "#121212";
          foreground = "#f6f5f4";
          color0 = "#1d1f21";
          color8 = "#c01c28";
          color1 = "#cc6666";
          color9 = "#ed333b";
          color2 = "#2ec27e";
          color10 = "#57e389";
          color3 = "#f5c211";
          color11 = "#f8e45c";
          color4 = "#1e78e4";
          color12 = "#51a1ff";
          color5 = "#9841bb";
          color13 = "#c061cb";
          color6 = "#0ab9dc";
          color14 = "#4fd2fd";
          color7 = "#c0bfbc";
          color15 = "#f6f5f4";
        };
      };
      font = {
        normal = {
          # family = "JetBrainsMono Nerd Font";
          family = "SauceCodePro Nerd Font";
          style = "Regular";
        };
        size = fontSize;
      };
      key_bindings = [
        { key = 53; mods = "Shift"; mode = "Vi"; action = "SearchBackward"; }
        { key = "Return"; mods = "Shift"; chars = "\\x1b[13;2u"; }
        { key = "Return"; mods = "Control"; chars = "\\x1b[13;5u"; }
      ];
      hints.enabled = [
        {
          regex = ''(mailto:|gemini:|gopher:|https:|http:|news:|file:|git:|ssh:|ftp:)[^\u0000-\u001F\u007F-\u009F<>"\\s{-}\\^⟨⟩`]+'';
          command = "${pkgs.mimeo}/bin/mimeo";
          post_processing = true;
          mouse.enabled = true;
        }
      ];
      selection.save_to_clipboard = true;
      shell.program = "${pkgs.zsh}/bin/zsh";
      window = {
        decorations = "none";
        opacity = 0.92;
        padding = {
          x = 5;
          y = 5;
        };
      };
    };
  };
}

