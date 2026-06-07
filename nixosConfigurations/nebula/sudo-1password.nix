{ ... }:
let
  # Public half of the ed25519 key stored in 1Password — the same key that signs
  # commits (see home/git/.config/git/config / allowed_signers).
  sudoSshKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy kris@1password";
in
{
  # Trusted keys for pam_ssh_agent_auth. Must NOT be user-writable, so we ship it
  # via /etc (a root-owned symlink into the nix store) rather than ~/.ssh.
  environment.etc."ssh/sudo_authorized_keys".text = sudoSshKey + "\n";

  security.pam.sshAgentAuth = {
    enable = true;
    authorizedKeysFiles = [ "/etc/ssh/sudo_authorized_keys" ];
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
