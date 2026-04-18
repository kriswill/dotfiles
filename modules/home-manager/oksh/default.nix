{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.kriswill.oksh;
in
{
  options.kriswill.oksh.enable = lib.mkEnableOption "kris' oksh setup";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.oksh ];

    # $ENV is sourced by oksh on interactive start (POSIX behavior).
    home.sessionVariables.ENV = "$HOME/.kshrc";

    home.file.".kshrc".source = config.lib.file.mkOutOfStoreSymlink (
      "${config.home.homeDirectory}/src/dotfiles/config/oksh/kshrc"
    );
  };
}
