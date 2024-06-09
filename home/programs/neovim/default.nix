{ config, pkgs, ... }:
let
  # path to my actual ~/.config -- use to link files from home-manager source
  configDir = config.home.homeDirectory + "/.config";
  nvimDir = configDir + "/home-manager/programs/neovim/nvim";
  ln = config.lib.file.mkOutOfStoreSymlink;
in
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };

  xdg.configFile."nvim/lua".source = ln nvimDir + "/lua";
  xdg.configFile."nvim/ftplugin".source = ln nvimDir + "/ftplugin";
  xdg.configFile."nvim/init.lua".source = ln nvimDir + "/init.lua";
  xdg.configFile."nvim/lazy-lock.json".source = ln nvimDir + "/lazy-lock.json";
}
