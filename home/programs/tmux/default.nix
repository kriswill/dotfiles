{
  config,
  pkgs,
  ...
}:
let
  configDir = config.home.homeDirectory + "/src/dotfiles/config/tmux";
  ln = config.lib.file.mkOutOfStoreSymlink;
in
{
  home.packages = with pkgs; [ tmux ];
  xdg.configFile = {
    "tmux/tmux.conf".source = ln configDir + "/tmux.conf";
  };
}
