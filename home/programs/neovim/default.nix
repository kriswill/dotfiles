{ config, pkgs, ... }:

with pkgs;
{
  programs.neovim = {
    enable = true;
    package = neovim-unwrapped;
    viAlias = true;
    vimAlias = true;
    withRuby = false;

    extraPackages = [
      # Formatters
      black # Python
      isort
      luajitPackages.jsregexp # luasnip
      nixpkgs-fmt
      prettierd # Multiple language formatter
      shfmt # Shell
      stylua # Lua

      # LSP
      lua-language-server
      lua5_1
      luarocks
      marksman

      go_1_23
      (go-tools.override { buildGoModule = buildGo123Module; })

      # tools
      cargo
      cmake
      fswatch # file watcher - replaces libuv.fs_event in neovim v0.10
      fzf
      git
      gnumake
      imagemagick
      nodejs
      sqlite
      tree-sitter
      wget
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
