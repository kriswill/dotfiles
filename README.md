# Kris' Nix Configuration **WORK-IN-PROGRESS**



## If /boot gets filled up with kernel generations

When frequently rebuilding the OS, sometimes the `/boot` partition will
fill up with generations and alternate Linux kernel versions.  If the disk fills
up then it will not be possible to `nixos rebuild`.

Use the following command to clear out old kernels/generations:

  ```sh
  sudo /run/current-system/bin/switch-to-configuration switch
  ```
## THINGS FOR LATER

### Backups

* [Kopia nix config](https://github.com/xddxdd/nixos-config/blob/8eeba4e85b70a6ccf0830d8fb743c34a12d6239e/nixos/server-components/backup.nix)