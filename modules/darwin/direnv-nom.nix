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
      diffCmd =
        if cfg.diff == "nvd" then
          "${lib.getExe pkgs.nvd} diff"
        else if cfg.diff == "native" then
          "nix store diff-closures"
        else
          null;

      # Wrapper text is shared with the NixOS twin (modules/nixos/direnv-nom.nix).
      wrapper = import ../../lib/direnv-nom-wrapper.nix { inherit lib pkgs diffCmd; };
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
