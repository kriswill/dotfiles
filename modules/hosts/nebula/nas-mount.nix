# On-demand SMB mount of the UNAS-PRO (192.168.0.82) personal drive's
# backups/wowdps-journal folder: the destination for the wowdps-suite
# coordinator's daily journal snapshots (the live SQLite journal stays on
# local disk and is never opened over SMB). SQLite cannot write a database
# directly here ("database is locked"), so the tool snapshots on local disk and
# copies the finished files over.
#
# Owner-only (k, 0600/0700): the snapshots include a private prompt log and the
# backup tool refuses a destination others can read. With no SMB unix
# extensions, these client-side modes are what the kernel enforces.
#
# Automount + nofail + short timeouts: nothing touches the NAS until the path is
# first accessed, a NAS that is down only fails that access (never boot or a
# login), and the mount drops after idling.
#
# Credentials: the `nas-smb-credentials` sops key in secrets.yaml is a cifs
# credentials file (username=/password= lines), written from the 1Password item
# "UNAS-PRO (k)". sops-nix decrypts it root-only; mount.cifs runs as root.
{
  configurations.nixos.nebula.module =
    { config, ... }:
    {
      boot.supportedFilesystems = [ "cifs" ]; # pulls in cifs-utils (mount.cifs)

      sops.secrets.nas-smb-credentials = { };

      fileSystems."/mnt/nas/wowdps-journal" = {
        # Personal-Drive is the SMB name of the UniFi Drive shown as "Kris's Drive".
        device = "//192.168.0.82/Personal-Drive/backups/wowdps-journal";
        fsType = "cifs";
        options = [
          "credentials=${config.sops.secrets.nas-smb-credentials.path}"
          "uid=1000" # k
          "gid=100" # users
          "file_mode=0600"
          "dir_mode=0700"
          "nosuid"
          "nodev"
          "noexec"
          "_netdev"
          "noauto"
          "nofail"
          "x-systemd.automount" # mount lazily on first access
          "x-systemd.idle-timeout=10min" # unmount when unused
          "x-systemd.device-timeout=5s"
          "x-systemd.mount-timeout=10s"
        ];
      };
    };
}
