# GnuPG agent on macOS — the darwin twin of modules/nixos/gpg.nix. Backs `pass`
# (modules/darwin/pass.nix) and ad-hoc gpg use; the gnupg *package* was already
# installed via user-packages.nix ("signature verifier"), this adds the launchd
# user agent + GPG_TTY wiring.
{
  flake.modules.darwin.gpg =
    { lib, ... }:
    {
      programs.gnupg.agent = {
        enable = true;
        # SSH auth and git signing go through the 1Password agent (op-ssh-sign,
        # ~/.ssh/config IdentityAgent) — gpg-agent must NOT claim SSH_AUTH_SOCK.
        enableSSHSupport = lib.mkDefault false;
      };
    };
}
