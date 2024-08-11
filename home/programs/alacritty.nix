{ pkgs, ... }:

let
  fontSize = 14;
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
        };
        normal = {
          black = "#1d1f21";
          red = "#ed333b";
          green = "#2ec27e";
          yellow = "#f5c211";
          blue = "#1e78e4";
          magenta = "#9841bb";
          cyan = "#0ab9dc";
          white = "#c0bfbc";
        };
        bright = {
          black = "#5e5c64";
          red = "#cc6666";
          green = "#57e389";
          yellow = "#f8e45c";
          blue = "#51a1ff";
          magenta = "#c061cb";
          cyan = "#4fd2fd";
          white = "#f6f5f4";
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
      keyboard.bindings = [
        {
          key = 53;
          mods = "Shift";
          mode = "Vi";
          action = "SearchBackward";
        }
        {
          key = "Return";
          mods = "Shift";
          chars = "\\\\x1b[13;2u";
        }
        {
          key = "Return";
          mods = "Control";
          chars = "\\\\x1b[13;5u";
        }
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
        opacity = 0.87;
        dimensions = {
          columns = 120;
          lines = 50;
        };
        padding = {
          x = 10;
          y = 10;
        };
      };
    };
  };
}
