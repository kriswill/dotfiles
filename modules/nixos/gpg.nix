# GnuPG agent — moved out of nebula's configuration.nix so it's class-wide and
# mirrors modules/darwin/gpg.nix. Backs `pass` (modules/nixos/pass.nix) and
# ad-hoc gpg use.
{
  flake.modules.nixos.gpg =
    { lib, ... }:
    {
      programs.gnupg.agent = {
        enable = true;
        # SSH auth and git signing go through the 1Password agent (op-ssh-sign,
        # sudo-1password.nix) — gpg-agent must NOT claim SSH_AUTH_SOCK.
        enableSSHSupport = lib.mkDefault false;
      };
    };
}
