{
  configurations.nixos.nebula.module =
    { ... }:
    let
      # Public half of the ed25519 key stored in 1Password — the same key that signs
      # commits (see home/git/.config/git/config / allowed_signers).
      sudoSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy kris@1password";
    in
    {
      # Trusted keys for pam_ssh_agent_auth. The module does a strict StrictModes check on
      # the *real* path of this file and refuses if any parent dir is group/other-writable.
      # An `environment.etc` entry is a symlink into /nix/store (group-writable, mode 1775),
      # which fails that check — so we materialize a real root-owned file via tmpfiles whose
      # realpath stays entirely under root-owned /etc.
      systemd.tmpfiles.rules = [
        "d /etc/sudo-ssh-keys 0755 root root -"
        "f+ /etc/sudo-ssh-keys/k 0444 root root - ${sudoSshKey}"
      ];

      security.pam.sshAgentAuth = {
        enable = true;
        authorizedKeysFiles = [ "/etc/sudo-ssh-keys/k" ];
      };

      # Add the ssh-agent auth step to the *sudo* PAM stack only (installed as
      # `auth sufficient` → falls back to password when the agent is unreachable, e.g.
      # in a TTY console or with the 1Password GUI closed — so it can never lock you out).
      security.pam.services.sudo.sshAgentAuth = true;
      # NixOS adds `Defaults env_keep+=SSH_AUTH_SOCK` to sudoers automatically when the
      # above is set, so pam_ssh_agent_auth.so can see the agent socket — no extra config.

      # Point the session at the 1Password agent socket so sudo (and ssh) find it.
      # In a TTY this path won't have a live agent, so sudo just falls back to a password.
      environment.sessionVariables.SSH_AUTH_SOCK = "\${HOME}/.1password/agent.sock";

      # gnome-keyring (pulled in by the niri desktop) ships gcr-ssh-agent, which otherwise
      # claims SSH_AUTH_SOCK (=/run/user/$UID/gcr/ssh) and shadows the 1Password agent.
      # Disable just its ssh-agent so the 1Password socket above wins; keyring secrets/
      # pkcs11 stay enabled.
      services.gnome.gcr-ssh-agent.enable = false;
    }

  ;
}
