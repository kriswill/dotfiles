# A second, key-only sshd on port 2122: the NixOS twin of
# ../darwin/agent-remote.nix, so every managed machine answers Herdr on the
# same port.
#
# sshd.service (port 22) is left exactly as snowglobe-factory configures it.
# This is a separate systemd unit running the same sshd binary against the
# same /etc/ssh/sshd_config, so it shares the host keys and the authorized
# keys (users.users.<name>.openssh.authorizedKeys); a client sees one host
# identity on both ports. Stopping or masking sshd.service does not stop it.
#
# What differs from the darwin twin:
# - a systemd service, not a launchd daemon. It copies sshd.service's own
#   settings (Type=notify-reload, KillMode=process so a restart does not
#   kill logged-in sessions, Restart=always), and logs to the journal
#   (`journalctl -u agent-remote`), not to a file;
# - host keys come from NixOS's sshd-keygen.service, which this unit orders
#   itself after; there is no `ssh-keygen -A` step;
# - the NixOS firewall is on and only opens services.openssh.ports, so the
#   port is opened here;
# - universal, with no options: nebula is the only host in the nixos class.
#
# The -o flags are read before the file and win over it: the port, no pid
# file (sshd.service owns /run/sshd.pid), and no password or
# keyboard-interactive login. Port 22 on nebula is already key-only; the
# flags keep this port so if that ever changes.
{
  flake.modules.nixos.agent-remote =
    { config, lib, ... }:
    let
      port = 2122;
      sshd = lib.getExe' config.services.openssh.package "sshd";
      sshdArgs = [
        "-D" # foreground: systemd supervises it
        "-e" # log to stderr, which systemd sends to the journal
        "-f"
        "/etc/ssh/sshd_config"
        "-p"
        (toString port)
        "-o"
        "PidFile=none"
        "-o"
        "PasswordAuthentication=no"
        "-o"
        "KbdInteractiveAuthentication=no"
      ];
    in
    {
      assertions = [
        {
          assertion = config.services.openssh.enable;
          message = "agent-remote reuses /etc/ssh/sshd_config, the sshd user and the host keys that services.openssh.enable provides.";
        }
      ];

      systemd.services.agent-remote = {
        description = "Key-only SSH daemon on port ${toString port}";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          "sshd-keygen.service"
        ];
        wants = [ "sshd-keygen.service" ];
        # Pick up sshd_config changes on a rebuild, as sshd.service does.
        restartTriggers = [ config.environment.etc."ssh/sshd_config".source ];
        serviceConfig = {
          Type = "notify-reload";
          ExecStart = "${sshd} ${lib.escapeShellArgs sshdArgs}";
          KillMode = "process";
          Restart = "always";
        };
      };

      networking.firewall.allowedTCPPorts = [ port ];
    };
}
