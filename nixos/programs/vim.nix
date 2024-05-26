{ pkgs, pkgs-unstable, ... }:

{
  environment.systemPackages = with pkgs.unstable; [
    (neovim.override {
      vimAlias = true;
      configure = {
        packages.myPlugins = with pkgs.unstable.vimPlugins; {
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
