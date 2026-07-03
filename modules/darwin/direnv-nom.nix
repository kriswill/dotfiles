# Wraps nix-direnv's internal _nix() function to pipe build logs through
# nix-output-monitor (nom) for pretty output during `use flake` in .envrc.
# System-level port of the old home-manager direnv-nom module.
#
# direnv sources ~/.config/direnv/lib/*.sh alphabetically. nix-direnv's stdlib
# is linked there as nix-direnv.sh (modules/darwin/direnv.nix), so this
# zz-nom-wrapper.sh loads after it and can redefine _nix(). Only print-dev-env
# is wrapped (it triggers the actual build); other subcommands like build and
# flake archive pass through unchanged. The wrapper bakes /nix/store paths (nom,
# readlink, the closure-diff tool), so — like tmux's plugins.conf — it can't be
# a static stow file; it's generated here and linked during activation.
{
  flake.modules.darwin.direnv-nom =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.programs.direnv-nom;
      nom = lib.getExe pkgs.nix-output-monitor;
      readlink = "${pkgs.coreutils}/bin/readlink";
      diffCmd =
        if cfg.diff == "nvd" then
          "${lib.getExe pkgs.nvd} diff"
        else if cfg.diff == "native" then
          "nix store diff-closures"
        else
          null;

      wrapper = pkgs.writeText "zz-nom-wrapper.sh" ''
        # Wrap nix-direnv's _nix() to pipe build logs through nix-output-monitor.
        # Loaded after nix-direnv.sh (alphabetical: zz > nix-direnv).
        if declare -f _nix > /dev/null 2>&1; then
          eval "$(declare -f _nix | sed '1s/_nix/_nix_direnv_original/')"

          _nix() {
            case "''${1:-}" in
              print-dev-env)
                ${lib.optionalString (diffCmd != null) ''
                  # Capture old profile store path before the build
                  local _nom_old=""
                  local _nom_tmp_profile=""
                  local _nom_arg
                  local _nom_next_is_profile=0
                  for _nom_arg in "$@"; do
                    if [[ $_nom_next_is_profile -eq 1 ]]; then
                      _nom_tmp_profile="$_nom_arg"
                      break
                    fi
                    [[ "$_nom_arg" == "--profile" ]] && _nom_next_is_profile=1
                  done
                  if [[ -n "$_nom_tmp_profile" ]]; then
                    local _nom_layout_dir
                    _nom_layout_dir="$(dirname "$_nom_tmp_profile")"
                    for _nom_f in "$_nom_layout_dir"/flake-profile-*; do
                      [[ -e "$_nom_f" ]] || continue
                      [[ "$_nom_f" == *.rc ]] && continue
                      _nom_old="$(${readlink} -f "$_nom_f")"
                      break
                    done
                  fi
                ''}
                _nix_direnv_original --log-format internal-json -v "$@" 2> >("${nom}" --json)
                local _nom_rc=$?
                ${lib.optionalString (diffCmd != null) ''
                  # Show closure diff if build succeeded and profile changed
                  if [[ $_nom_rc -eq 0 && -n "$_nom_tmp_profile" && -e "$_nom_tmp_profile" ]]; then
                    local _nom_new
                    _nom_new="$(${readlink} -f "$_nom_tmp_profile")"
                    if [[ -n "$_nom_old" && -n "$_nom_new" && "$_nom_old" != "$_nom_new" ]]; then
                      ${diffCmd} "$_nom_old" "$_nom_new" >&2 || true
                    fi
                  fi
                ''}
                return "$_nom_rc"
                ;;
              *)
                _nix_direnv_original "$@"
                ;;
            esac
          }
        fi
      '';
    in
    {
      # The module itself is universal (always mounted, no enable); this is a
      # behavior setting, not a gate.
      options.programs.direnv-nom.diff = lib.mkOption {
        type = lib.types.enum [
          "nvd"
          "native"
          "none"
        ];
        default = "nvd";
        description = "Closure diff tool: nvd (nh-style formatted output), native (nix store diff-closures), or none to disable";
      };

      config = {
        # Order 1600: after dotfiles-stow (1500), alongside direnv.nix which links
        # nix-direnv.sh into the same lib dir. Run as the user so the link isn't
        # root-owned; ln -sfn keeps the store path current across bumps.
        system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
          /usr/bin/sudo -u k --set-home /bin/sh -c '
            mkdir -p /Users/k/.config/direnv/lib
            ln -sfn ${wrapper} /Users/k/.config/direnv/lib/zz-nom-wrapper.sh
          '
        '';
      };
    };
}
