{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    (neovim.override {
      vimAlias = true;
      configure = {
        packages.myPlugins = with pkgs.vimPlugins; {
          start = [
            vim-lastplace
            vim-nix
          ];
          opt = [ ];
        };
        customRC = ''
          set nocompatible
          set backspace=indent,eol,start
        '';
      };
    })
  ];
}
