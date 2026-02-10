{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.kriswill.tmux.enable = lib.mkEnableOption "Kris' tmux";
  config = lib.mkIf config.kriswill.tmux.enable (
    let
      configDir = config.home.homeDirectory + "/src/dotfiles/config/tmux";
      ln = config.lib.file.mkOutOfStoreSymlink;
      whichKey = pkgs.tmuxPlugins.tmux-which-key;
    in
    {
      home.packages = [ pkgs.tmux ];
      xdg.configFile = {
        "tmux/tmux.conf".source = ln configDir + "/tmux.conf";
        "tmux/plugins.conf".text = ''
          set -g @tmux-which-key-xdg-enable 1
          run-shell 'mkdir -p ~/.local/share/tmux/plugins/tmux-which-key && touch ~/.local/share/tmux/plugins/tmux-which-key/init.tmux'
          run-shell ${whichKey.rtp}
        '';
        "tmux/plugins/tmux-which-key/config.yaml".source = ln configDir + "/config.yaml";
      };
    }
  );
}
