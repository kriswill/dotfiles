{
  configurations.nixos.nebula.module = {
    # Permanent read-only mount of the Windows NTFS partition (the other NVMe).
    # Read-only is deliberate: it avoids any corruption risk and still mounts even
    # when Windows Fast Startup / hibernation left the volume "dirty". Good enough
    # for copying files off Windows; switch to a read-write ntfs-3g config only
    # after disabling Fast Startup in Windows.

    # Pulls in the ntfs-3g userspace driver.
    boot.supportedFilesystems = [ "ntfs" ];

    fileSystems."/mnt/windows" = {
      # /dev/nvme1n1p3, LABEL="Windows"
      device = "/dev/disk/by-uuid/902A59752A5958F4";
      fsType = "ntfs-3g";
      options = [
        "ro"
        "uid=1000" # k
        "gid=100" # users
        "umask=022"
        "windows_names"
        "nofail" # don't fail boot if the disk is absent
        "x-systemd.automount" # mount lazily on first access
        "x-systemd.device-timeout=5s"
      ];
    };
  }

  ;
}
