# minimal neovim for working with root or during installation
{ pkgs, lib, ... }:

with pkgs.unstable; {
  programs.neovim = {
    enable = true;
    package = neovim-unwrapped;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    configure = {
      customRC = "luafile ${./init.lua}";
      packages.myPlugins = with vimPlugins; {
        start = [
          nvim-fzf
          nvim-treesitter.withAllGrammars
          plenary-nvim # needed for telescope
          telescope-file-browser-nvim
          telescope-fzy-native-nvim
          telescope-nvim
          nvim-comment
          vim-lastplace
          vim-nix
          which-key-nvim
          lightline-vim
        ];
        opt = [ ];
      };
    };
  };
  environment.systemPackages = [ tree-sitter stylua fd fzf wget fswatch ];
}
