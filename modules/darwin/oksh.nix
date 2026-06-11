# Kris' oksh (system-level port of the old home-manager module).
#
# The config — ~/.kshrc and the starship init script it sources — lives in the
# stow tree (home/oksh/), symlinked into ~ by dotfiles-stow.nix. Only the
# package and the $ENV pointer (POSIX: sourced by oksh on interactive start)
# are nix's business.
{
  flake.modules.darwin.oksh =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    {
      options.kriswill.oksh.enable = lib.mkEnableOption "Kris' oksh";
      config = lib.mkIf config.kriswill.oksh.enable {
        environment.systemPackages = [ pkgs.oksh ];
        environment.variables.ENV = "$HOME/.kshrc";
      };
    };
}
