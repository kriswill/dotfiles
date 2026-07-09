# Auto-mount the UNAS Pro 4's Personal-Drive SMB share at login via a launchd
# user agent. See docs/unifi-dream-machine.md for how nas.home.lan (a UniFi
# "Local DNS Record", not a static DNS entry) was set up. `-N` is required —
# a launchd agent has no session to show an interactive password sheet, so it
# only works because macOS already has a matching keychain entry (confirmed
# 2026-07-09: the same entry serves both the Bonjour and DNS hostnames, since
# macOS's SMB client keys off the server's negotiated identity, not the
# literal string used to connect — see the manual's "two mechanisms" note).
{
  flake.modules.darwin.nas-mount =
    { lib, config, pkgs, ... }:
    let
      cfg = config.services.nas-mount;
      home = "/Users/k";
      mountPoint = "${home}/nas";
      share = "//k@nas.home.lan/Personal-Drive";
      mountScript = pkgs.writeShellScript "nas-mount" ''
        set -euo pipefail
        mkdir -p "${mountPoint}"
        if ! /sbin/mount | grep -qF " on ${mountPoint} "; then
          /sbin/mount_smbfs -N "${share}" "${mountPoint}"
        fi
      '';
    in
    {
      options.services.nas-mount.enable = lib.mkEnableOption "auto-mount the UNAS Pro 4 Personal-Drive SMB share at login";
      config = lib.mkIf cfg.enable {
        launchd.user.agents.nas-mount = {
          serviceConfig = {
            ProgramArguments = [ "${mountScript}" ];
            RunAtLoad = true;
            StartInterval = 300; # retry if the NAS/network wasn't ready at login
            StandardOutPath = "${home}/Library/Logs/nas-mount.log";
            StandardErrorPath = "${home}/Library/Logs/nas-mount.log";
          };
        };
      };
    };
}
