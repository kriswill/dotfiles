{ config, pkgs, ... }:

with pkgs;
{
  programs.neovim = {
    enable = true;
    package = neovim-unwrapped;
    viAlias = true;
    vimAlias = true;
    extraPackages = [
      # Formatters
      nixpkgs-fmt
      black # Python
      prettierd # Multiple language formatter
      shfmt # Shell
      isort
      stylua # Lua

      # LSP
      lua-language-server
      lua5_1
      luarocks
      nil
      nixd
      # rustTools
      go_1_22
      (go-tools.override { buildGoModule = buildGo122Module; })

      # tools
      tree-sitter
      git
      cmake
      gnumake
      fzf
      fswatch # file watcher - replaces libuv.fs_event in neovim v0.10
      sqlite
      nodejs
    ];
  };
} // (
let
  # used to link files to .config/nvim/*
  nvimDir = config.home.homeDirectory + "/src/dotfiles/home/programs/neovim/nvim";
  ln = config.lib.file.mkOutOfStoreSymlink;
in
{
  xdg.configFile = {
    "nvim/lua".source = ln nvimDir + "/lua";
    "nvim/ftplugin".source = ln nvimDir + "/ftplugin";
    "nvim/init.lua".source = ln nvimDir + "/init.lua";
    "nvim/lazy-lock.json".source = ln nvimDir + "/lazy-lock.json";
  };
})
