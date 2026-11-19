# A second, key-only sshd on its own port, separate from macOS Remote Login.
#
# Runs nixpkgs OpenSSH with its own immutable config, not Apple's binary or
# /etc/ssh/sshd_config. The Darwin package has no PAM support, so neither the
# Remote Login switch nor its com.apple.access_ssh ACL controls this daemon.
#
# Host keys and declarative authorized keys still come from nix-darwin;
# its openssh activation creates missing host keys before launchd starts.
#
# The application firewall holds every inbound connection to a binary it
# does not know until someone answers a desktop prompt, so clients connect
# but never get a banner. Each OpenSSH rebuild gives sshd a new store path,
# so activation adds the current path to the firewall before launchd
# restarts the daemon.
{
  flake.modules.darwin.agent-remote =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.services.agent-remote;
      sshdConfig = pkgs.writeText "agent-remote-sshd_config" ''
        Port ${toString cfg.port}
        PidFile none
        ${lib.concatMapStringsSep "\n" (key: "HostKey ${key.path}") config.services.openssh.hostKeys}

        AuthenticationMethods publickey
        PubkeyAuthentication yes
        PasswordAuthentication no
        KbdInteractiveAuthentication no
        PermitEmptyPasswords no

        AuthorizedKeysFile .ssh/authorized_keys
        # Match nix-darwin's reader for its symlinked, declarative keys.
        AuthorizedKeysCommand /bin/cat /etc/ssh/nix_authorized_keys.d/%u
        AuthorizedKeysCommandUser _sshd

        AcceptEnv LANG LC_*
        Subsystem sftp internal-sftp
      '';
      sshd = lib.getExe' pkgs.openssh "sshd";
      sshdArgs = [
        "-D" # foreground: launchd supervises it
        "-e" # log to stderr, captured in the log file below
        "-f"
        (toString sshdConfig)
      ];
    in
    {
      options.services.agent-remote = {
        enable = lib.mkEnableOption "a second, key-only sshd on its own port";
        port = lib.mkOption {
          type = lib.types.port;
          default = 2122;
          description = ''
            TCP port the second sshd listens on. 2122 is outside the
            well-known range; IANA lists it for "CauPC Remote Control",
            which nothing here uses.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.services.openssh.hostKeys != [ ];
            message = "agent-remote requires services.openssh.hostKeys for its server identity.";
          }
        ];

        # preActivation runs before launchd reloads the daemon on a new path.
        # `--getappblocked` reports "permitted" for any binary it has no rule
        # for, and a managed firewall refuses `--add` with exit 0, so the
        # check reads the `--listapps` entry itself.
        system.activationScripts.preActivation.text = ''
          # --- agent-remote: let the application firewall accept sshd ---
          agent_remote_fw=/usr/libexec/ApplicationFirewall/socketfilterfw
          agent_remote_sshd=${sshd}
          agent_remote_fw_allows_sshd() {
            local apps
            apps="$("$agent_remote_fw" --listapps 2>/dev/null)" || return 1
            /usr/bin/awk -v p="$agent_remote_sshd" '
              index($0, p) { getline; ok = /Allow incoming connections/; exit }
              END { exit !ok }' <<<"$apps"
          }
          if ! agent_remote_fw_allows_sshd; then
            "$agent_remote_fw" --add "$agent_remote_sshd" >/dev/null 2>&1 || true
            "$agent_remote_fw" --unblockapp "$agent_remote_sshd" >/dev/null 2>&1 || true
            if agent_remote_fw_allows_sshd; then
              echo "agent-remote: application firewall now allows $agent_remote_sshd"
            elif [[ "$("$agent_remote_fw" --getglobalstate 2>/dev/null)" == *enabled* ]]; then
              echo "agent-remote: the application firewall did not accept $agent_remote_sshd;" >&2
              echo "agent-remote: approve the sshd prompt on this Mac's desktop, or port ${toString cfg.port} hangs" >&2
            fi
          fi
        '';

        launchd.daemons.agent-remote = {
          script = ''
            set -euo pipefail
            exec ${sshd} ${lib.escapeShellArgs sshdArgs}
          '';
          serviceConfig = {
            RunAtLoad = true;
            KeepAlive = true;
            StandardOutPath = "/var/log/agent-remote.log";
            StandardErrorPath = "/var/log/agent-remote.log";
          };
        };
      };
    };
}
