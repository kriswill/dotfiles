# Wraps nix-direnv's internal _nix() function to pipe build logs through
# nix-output-monitor (nom) for pretty output during `use flake` in .envrc.
#
# Direnv sources ~/.config/direnv/lib/*.sh alphabetically. nix-direnv installs
# as hm-nix-direnv.sh, so zz-nom-wrapper.sh loads after it and can redefine
# _nix(). Only print-dev-env and build subcommands are wrapped (they trigger
# actual builds); other subcommands like flake archive pass through unchanged.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.kriswill.direnv-nom;
  nom = lib.getExe pkgs.nix-output-monitor;
in
{
  options.kriswill.direnv-nom.enable = lib.mkEnableOption "nom integration for nix-direnv";

  config = lib.mkIf (cfg.enable && config.programs.direnv.enable && config.programs.direnv.nix-direnv.enable) {
    xdg.configFile."direnv/lib/zz-nom-wrapper.sh".text = ''
      # Wrap nix-direnv's _nix() to pipe build logs through nix-output-monitor.
      # Loaded after hm-nix-direnv.sh (alphabetical: zz > hm).
      if declare -f _nix > /dev/null 2>&1; then
        eval "$(declare -f _nix | sed '1s/_nix/_nix_direnv_original/')"

        _nix() {
          case "''${1:-}" in
            print-dev-env|build)
              _nix_direnv_original --log-format internal-json -v "$@" 2> >("${nom}" --json)
              ;;
            *)
              _nix_direnv_original "$@"
              ;;
          esac
        }
      fi
    '';
  };
}
