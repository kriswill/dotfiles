# nix-darwin module for pam-tid-gate, exported as `darwinModules.pam-tid-gate`.
# Parameterized over this flake's `self` so `package` defaults to the flake's
# own build for the host system; consumers need no overlay.
self:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.security.pam-tid-gate;
in
{
  options.security.pam-tid-gate = {
    enable = lib.mkEnableOption ''
      Touch ID for sudo only while someone can reach this Mac's own Touch ID
      readers: under sshd, at a locked screen or the login window, after
      idleSeconds without local input, or while Universal Control is linked,
      sudo asks for the password instead of waiting on a prompt nobody can
      answer'';
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.pam-tid-gate;
      defaultText = lib.literalExpression "pam-tid-gate.packages.\${system}.pam-tid-gate";
      description = "The pam-tid-gate package to use.";
    };
    idleSeconds = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 300;
      description = ''
        Seconds without local keyboard or mouse input after which sudo uses
        the password. Universal Control input counts as local input. 0 turns
        the idle rule off.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # The CLI answers "why did sudo ask for my password?".
    environment.systemPackages = [ cfg.package ];

    security.pam.services.sudo_local = {
      # The gate calls pam_tid itself; a plain pam_tid line would prompt
      # whether or not anyone can answer it.
      touchIdAuth = lib.mkForce false;
      # After anything else sudo_local carries (pam_reattach must run first).
      text = lib.mkAfter ''
        auth       sufficient     ${cfg.package}/lib/pam/pam_tid_gate.so idle=${toString cfg.idleSeconds}
      '';
    };
  };
}
