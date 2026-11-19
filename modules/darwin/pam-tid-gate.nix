# pam-tid-gate ships its nix-darwin module with its sub-flake
# (./flakes/pam-tid-gate/darwin-module.nix); import it into the Dendritic
# module set so hosts pick it up like any in-tree modules/darwin/* module. The
# module defaults security.pam-tid-gate.package to the sub-flake's own package,
# so no overlay is needed. Enable per host with
# `security.pam-tid-gate.enable = true;`.
#
# Repo glue: core.nix writes /etc/pam.d/sudo_local straight through
# environment.etc (pam_reattach ignore_ssh, then pam_tid), where the gate's
# module can't remove the pam_tid line. Where the gate is on, sudo_local is
# exactly nix-darwin's sudo_local.text instead: the reattach line first, then
# the gate. Hosts without the gate keep core.nix's file unchanged.
{ inputs, ... }:
{
  flake.modules.darwin.pam-tid-gate =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.pam-tid-gate.darwinModules.pam-tid-gate ];

      config = lib.mkIf config.security.pam-tid-gate.enable {
        security.pam.services.sudo_local.text = lib.mkBefore ''
          # Reattach to the GUI session so Touch ID works for sudo inside tmux
          auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so ignore_ssh
        '';
        environment.etc."pam.d/sudo_local".text = lib.mkForce config.security.pam.services.sudo_local.text;
      };
    };
}
