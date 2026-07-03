# Wraps nix-direnv's internal _nix() function to pipe build logs through
# nix-output-monitor (nom) for pretty output during `use flake` in .envrc —
# the NixOS twin of modules/darwin/direnv-nom.nix. The wrapper text itself is
# shared (lib/direnv-nom-wrapper.nix); only the option declaration and the
# link mechanism (tmpfiles here, activation script on darwin) are per-class.
{
  flake.modules.nixos.direnv-nom =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      user = "k";
      home = "/home/k";
      cfg = config.programs.direnv-nom;
      diffCmd =
        if cfg.diff == "nvd" then
          "${lib.getExe pkgs.nvd} diff"
        else if cfg.diff == "native" then
          "nix store diff-closures"
        else
          null;

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
        systemd.tmpfiles.rules = [
          "d ${home}/.config/direnv 0755 ${user} users - -"
          "d ${home}/.config/direnv/lib 0755 ${user} users - -"
          "L+ ${home}/.config/direnv/lib/zz-nom-wrapper.sh - - - - ${wrapper}"
        ];
      };
    };
}
