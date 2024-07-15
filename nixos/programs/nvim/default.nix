# minimal neovim for working with root or during installation
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs.unstable; [
    (neovim.override {
      vimAlias = true;
      viAlias = true;
      configure = {
        packages.myPlugins = with pkgs.unstable.vimPlugins; {
          start = [
            nvim-fzf
            nvim-treesitter.withAllGrammars
            papercolor-theme
            plenary-nvim # needed for telescope
            telescope-file-browser-nvim
            telescope-fzy-native-nvim
            telescope-nvim
            vim-lastplace
            vim-nix
            which-key-nvim
          ];
          opt = [ ];
        };
        customRC = ''
        syntax enable
        set tabstop=4
        set shiftwidth=4
        set smartindent
        set autoindent
        set foldmethod=syntax
        set clipboard+=unnamedplus
        set nocompatible
        set backspace=indent,eol,start
        set number
        set relativenumber
        set termguicolors " 24-bit colors
        colorscheme PaperColor

        luafile ${./init.lua}
        '';
      };
    })
  ];
}
