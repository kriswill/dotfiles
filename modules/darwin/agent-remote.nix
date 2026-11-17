# A second, key-only sshd on its own port, separate from macOS Remote Login.
#
# Runs nixpkgs OpenSSH with its own immutable config, not Apple's binary or
# /etc/ssh/sshd_config. The Darwin package has no PAM support, so neither the
# Remote Login switch nor its com.apple.access_ssh ACL controls this daemon.
#
# Host keys and declarative authorized keys still come from nix-darwin;
# its openssh activation creates missing host keys before launchd starts.
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

        launchd.daemons.agent-remote = {
          script = ''
            set -euo pipefail
            exec ${lib.getExe' pkgs.openssh "sshd"} ${lib.escapeShellArgs sshdArgs}
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
