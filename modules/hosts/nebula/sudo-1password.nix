{
  configurations.nixos.nebula.module =
    { config, pkgs, ... }:
    let
      # Public half of the ed25519 key stored in 1Password — the same key that signs
      # commits (see home/git/.config/git/config / allowed_signers).
      sudoSshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy kris@1password";
      sudoKeyFile = "/etc/sudo-ssh-keys/k";

      # sudo-agent-gate: does the agent sudo would ask sign within 2 s? It runs
      # from pam_exec (as root: `seteuid`) just before pam_ssh_agent_auth. Exit
      # 0 lets pam_ssh_agent_auth run; anything else skips it, and sudo goes on
      # to the password: the terminal, or herdr-askpass's Herdr dialog for an
      # agent with no terminal. It never authenticates anyone itself, so at
      # worst sudo behaves as it did without it.
      #
      # Why: 1Password's agent, locked or not yet approving a program, holds a
      # signature request for 60 s behind a dialog on nebula's screen, which
      # nobody sees when you're working from k. Listing keys (`ssh-add -l`)
      # answers even while locked, so the probe signs, like
      # pam_ssh_agent_auth. 1Password approves programs separately: the probe
      # (ssh-keygen) needs its own Authorize once per approval period; until
      # then sudo goes to the password after 2 s, and the dialog stays on
      # nebula's screen until 1Password's 60 s run out.
      #
      # pam_exec passes only PAM's environment, so SSH_AUTH_SOCK comes from
      # sudo's own (/proc/$PPID/environ): the same agent pam_ssh_agent_auth
      # will use. The probe signs as the user (setpriv), as a client of
      # that agent normally would.
      sudoAgentGate = pkgs.writeShellApplication {
        name = "sudo-agent-gate";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gnused
          pkgs.getent
          pkgs.openssh
          pkgs.util-linux
        ];
        text = ''
          key=''${1:?usage: sudo-agent-gate <authorized key file> [seconds]}
          wait=''${2:-2}
          user=''${PAM_USER:-}
          log() { logger -t sudo-agent-gate "$*" || true; }

          [[ -n $user ]] || exit 1
          sock=$(tr '\0' '\n' </proc/"$PPID"/environ 2>/dev/null | sed -n 's/^SSH_AUTH_SOCK=//p' | head -n1) || sock=""
          if [[ -z $sock || ! -S $sock ]]; then
            exit 1 # no agent: pam_ssh_agent_auth would fail anyway
          fi
          home=$(getent passwd "$user" | cut -d: -f6)
          # As root (pam_exec seteuid) become the user; already the user (a
          # test run), stay: setpriv --init-groups needs root.
          as_user=()
          if [[ $(id -u) != "$(id -u "$user")" ]]; then
            as_user=(setpriv --reuid="$user" --regid="$(id -g "$user")" --init-groups --)
          fi

          if echo sudo-agent-gate |
            env -i PATH="$PATH" HOME="$home" SSH_AUTH_SOCK="$sock" \
              "''${as_user[@]}" \
              timeout -k 1 "$wait" ssh-keygen -Y sign -f "$key" -n sudo-agent-gate >/dev/null 2>&1; then
            exit 0
          fi
          log "the agent at $sock didn't sign for $user within ''${wait}s (1Password locked, or the probe not approved): skipping it, asking for the password"
          exit 1
        '';
      };
    in
    {
      # Trusted keys for pam_ssh_agent_auth. The module does a strict StrictModes check on
      # the *real* path of this file and refuses if any parent dir is group/other-writable.
      # An `environment.etc` entry is a symlink into /nix/store (group-writable, mode 1775),
      # which fails that check — so we materialize a real root-owned file via tmpfiles whose
      # realpath stays entirely under root-owned /etc.
      systemd.tmpfiles.rules = [
        "d /etc/sudo-ssh-keys 0755 root root -"
        "f+ ${sudoKeyFile} 0444 root root - ${sudoSshKey}"
      ];

      security.pam.sshAgentAuth = {
        enable = true;
        authorizedKeysFiles = [ sudoKeyFile ];
      };

      # Add the ssh-agent auth step to the *sudo* PAM stack only (installed as
      # `auth sufficient` → falls back to password when the agent is unreachable, e.g.
      # in a TTY console or with the 1Password GUI closed — so it can never lock you out).
      security.pam.services.sudo.sshAgentAuth = true;
      # NixOS adds `Defaults env_keep+=SSH_AUTH_SOCK` to sudoers automatically when the
      # above is set, so pam_ssh_agent_auth.so can see the agent socket — no extra config.

      # The gate (above), directly before pam_ssh_agent_auth: on success sudo
      # goes on to it; otherwise `default=1` skips exactly that one rule, so
      # nothing may sit between them (order is one less than its).
      security.pam.services.sudo.rules.auth.ssh_agent_gate = {
        order = config.security.pam.services.sudo.rules.auth.ssh_agent_auth.order - 1;
        control = "[success=ignore default=1]";
        modulePath = "${pkgs.linux-pam}/lib/security/pam_exec.so";
        args = [
          "quiet"
          "seteuid"
          "${sudoAgentGate}/bin/sudo-agent-gate"
          sudoKeyFile
        ];
      };

      # Point the session at the 1Password agent socket so sudo (and ssh) find it.
      # In a TTY this path won't have a live agent, so sudo just falls back to a password.
      # MUST be the unbraced literal `$HOME`: NixOS writes sessionVariables into
      # /etc/pam/environment via a plain replaceStrings ["$HOME"] ["@{HOME}"] —
      # a braced `${HOME}` is not matched, lands verbatim in the file, and
      # pam_env then resolves it as a (nonexistent) pam_env variable, silently
      # breaking the socket path for every PAM session.
      environment.sessionVariables.SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";

      # gnome-keyring (pulled in by the desktop session) ships gcr-ssh-agent, which otherwise
      # claims SSH_AUTH_SOCK (=/run/user/$UID/gcr/ssh) and shadows the 1Password agent.
      # Disable just its ssh-agent so the 1Password socket above wins; keyring secrets/
      # pkcs11 stay enabled.
      services.gnome.gcr-ssh-agent.enable = false;
    }

  ;
}
