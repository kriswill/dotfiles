{ pkgs, specialArgs, ... }:

let
  fontSize = 16; # if specialArgs.hidpi then 10 else 8;
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";
      bell = {
        animation = "EaseOutExpo";
        duration = 5;
        color = "#ffffff";
      };
      colors = {
        primary = {
          background = "#040404";
          foreground = "#c5c8c6";
        };
      };
      font = {
        normal = {
          family = "JetBrainsMono Nerd Font";
          style = "Medium";
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
        decorations = "full";
        opacity = 0.90;
        padding = {
          x = 5;
          y = 5;
        };
      };
    };
  };
}

