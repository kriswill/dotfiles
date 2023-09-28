# Kris' Nix Configuration **WORK-IN-PROGRESS**



## If /boot gets filled up with kernel generations

When frequently rebuilding the OS, sometimes the `/boot` partition will
fill up with generations and alternate Linux kernel versions.  If the disk fills
up then it will not be possible to `nixos rebuild`.

Use the following command to clear out old kernels/generations:

  ```sh
  sudo /run/current-system/bin/switch-to-configuration switch
  ```
