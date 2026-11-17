# A second, key-only sshd on its own port, separate from macOS Remote Login.
#
# The built-in service (system/com.openssh.sshd, port 22) is left exactly as
# macOS or services.remote-login has it; this is an extra launchd daemon
# running the same /usr/sbin/sshd in the foreground on another port. Turning
# Remote Login off in the Sharing pane does not stop it.
#
# It reads the stock /etc/ssh/sshd_config, so the nix-darwin drop-ins in
# /etc/ssh/sshd_config.d still apply: the same host keys and the same
# authorized keys (users.users.<name>.openssh.authorizedKeys, set in
# core.nix). The differences are passed as -o flags, which sshd reads before
# the file and which therefore win: the port, no pid file, and no password or
# keyboard-interactive login.
#
# UsePAM stays on, so the com.apple.access_ssh service ACL still decides who
# may log in (see remote-login.nix).
{
  flake.modules.darwin.agent-remote =
    { lib, config, ... }:
    let
      cfg = config.services.agent-remote;
      sshdArgs = [
        "-D" # foreground: launchd supervises it
        "-e" # log to stderr, captured in the log file below
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
            TCP port the second sshd listens on. 2122 is outside the
            well-known range; IANA lists it for "CauPC Remote Control",
            which nothing here uses.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        launchd.daemons.agent-remote = {
          # ssh-keygen -A only creates host keys that are missing, which is
          # the case on a Mac where Remote Login has never been turned on.
          script = ''
            /usr/bin/ssh-keygen -A
            exec /usr/sbin/sshd ${lib.escapeShellArgs sshdArgs}
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
