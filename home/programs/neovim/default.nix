{ config, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    package = pkgs.unstable.neovim-unwrapped;
    viAlias = true;
    vimAlias = true;
    extraPackages = with pkgs; [
      # Formatters
      alejandra # Nix
      black # Python
      prettierd # Multiple language formatter
      shfmt # Shell
      isort
      stylua # Lua

      # LSP
      lua-language-server
      nixd
      # rustTools
      go_1_22
      (go-tools.override { buildGoModule = buildGo122Module; })

      # tools
      git
      cmake
      gnumake
      fzf
      fswatch # file watcher - replaces libuv.fs_event in neovim v0.10
      sqlite
      nodejs
      wget # used by mason
    ];
  };
} // (
let
  # used to link files to .config/nvim/* 
  nvimDir = config.home.homeDirectory + "/src/dotfiles/home/programs/neovim/nvim";
  ln = config.lib.file.mkOutOfStoreSymlink;
in
{
  xdg.configFile."nvim/lua".source = ln nvimDir + "/lua";
  xdg.configFile."nvim/ftplugin".source = ln nvimDir + "/ftplugin";
  xdg.configFile."nvim/init.lua".source = ln nvimDir + "/init.lua";
  xdg.configFile."nvim/lazy-lock.json".source = ln nvimDir + "/lazy-lock.json";
})