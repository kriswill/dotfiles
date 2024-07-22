# minimal neovim for working with root or during installation
{ pkgs, lib, ... }:

{
  programs.neovim = {
    enable = true;
    package = pkgs.unstable.neovim-unwrapped;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    configure = {
      customRC = "luafile ${./init.lua}";
      packages.myPlugins = with pkgs.unstable.vimPlugins; {
        start = [
          nvim-fzf
          nvim-treesitter.withAllGrammars
#          papercolor-theme
          plenary-nvim # needed for telescope
          telescope-file-browser-nvim
          telescope-fzy-native-nvim
          telescope-nvim
          vim-lastplace
          vim-nix
          which-key-nvim
          lightline-vim
        ];
        opt = [ ];
      };
    };
  };
  environment.systemPackages = with pkgs.unstable; [
    tree-sitter
    stylua
    fd
    fzf
    wget
    fswatch
  ];
}
