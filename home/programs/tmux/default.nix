{
  pkgs,
  # lib,
  # inputs,
  ...
}:
with pkgs;
# let
#   inherit (lib) getExe;
#   minimal-tmux = inputs.minimal-tmux.packages.${system}.default;
# in
{
  home.packages = with pkgs; [ tmux ];

  # xdg.configFile = {
  #   "tmux/tmux.conf".source = ''
  #
  #   '';
  # programs.tmux = {
  #   enable = true;
  #   shell = getExe zsh;
  #   escapeTime = 5;
  #   baseIndex = 1;
  #   keyMode = "vi";
  #   mouse = true;
  #   shortcut = "space";
  #   terminal = "screen-256color";
  #   # plugins = with tmuxPlugins; [ vim-tmux-navigator ] ++ [ minimal-tmux ];
  #   plugins = with tmuxPlugins; [ vim-tmux-navigator ];
  #   extraConfig = ''
  #     set -g default-command ${getExe zsh}
  #     set -g default-terminal "xterm-ghostty"
  #     set-option -g status-position top
  #     set -g detach-on-destroy off
  #     set -g allow-passthrough on
  #     set-option -ag terminal-features 'xterm-256color:RGB'
  #     set-option -ag terminal-features 'cstyle'
  #
  #     bind -n S-Left previous-window
  #     bind -n S-Right next-window
  #   '';
  # };
}
