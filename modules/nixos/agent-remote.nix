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
# - an assertion requires services.openssh.enable, whose sshd_config, sshd
#   user and host keys this unit reuses.
#
# Same options as the darwin twin (services.agent-remote.enable / .port),
# off by default; nebula turns it on in modules/hosts/nebula/agent-remote.nix.
#
# The -o flags are read before the file and win over it: the port, no pid
# file (sshd.service owns /run/sshd.pid), and no password or
# keyboard-interactive login. Port 22 on nebula is already key-only; the
# flags keep this port so if that ever changes.
{
  flake.modules.nixos.agent-remote =
    { config, lib, ... }:
    let
      cfg = config.services.agent-remote;
      sshd = lib.getExe' config.services.openssh.package "sshd";
      sshdArgs = [
        "-D" # foreground: systemd supervises it
        "-e" # log to stderr, which systemd sends to the journal
        "-f"
        "/etc/ssh/sshd_config"
        "-p"
        (toString cfg.port)
        "-o"
        "PidFile=none"
        "-o"
        "PasswordAuthentication=no"
        "-o"
        "KbdInteractiveAuthentication=no"
      ];
    in
    {
      options.services.agent-remote = {
        enable = lib.mkEnableOption "a second, key-only sshd on its own port";
        port = lib.mkOption {
          type = lib.types.port;
          default = 2122;
          description = ''
            TCP port the second sshd listens on, also opened in the
            firewall. 2122 is outside the well-known range; IANA lists it
            for "CauPC Remote Control", which nothing here uses.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.services.openssh.enable;
            message = "agent-remote reuses /etc/ssh/sshd_config, the sshd user and the host keys that services.openssh.enable provides.";
          }
        ];

        systemd.services.agent-remote = {
          description = "Key-only SSH daemon on port ${toString cfg.port}";
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

        networking.firewall.allowedTCPPorts = [ cfg.port ];
      };
    };
}
