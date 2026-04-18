{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.kriswill.oksh;

  # oksh-specific starship init script, packaged as a derivation so the
  # kshrc can source it from a stable nix-store path instead of a
  # hand-maintained working-copy checkout.
  starshipInit = pkgs.writeTextFile {
    name = "starship-init-oksh.sh";
    text = builtins.readFile ./starship-init.sh;
  };
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

    # Install the starship-oksh init script at a stable path so kshrc
    # can source it without relying on a working-copy checkout.
    home.file.".config/oksh/starship-init.sh".source = starshipInit;
  };
}
