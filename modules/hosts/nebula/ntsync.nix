{
  # Load the ntsync driver at boot: Windows NT synchronisation objects
  # (mutexes, semaphores, events, multi-object waits) implemented in the
  # kernel, which Wine maps its own onto. GE-Proton 11 uses it whenever
  # /dev/ntsync can be opened (it sets WINENTSYNC=1; PROTON_NO_NTSYNC=1 opts
  # out) and otherwise falls back to fsync, its futex-based approximation.
  # The wineserver says which: "ntsync: up and running." or "fsync: up and
  # running.".
  #
  # nebula's kernel builds the driver as a module (CONFIG_NTSYNC=m). It
  # registers /dev/ntsync with a dynamic minor, so no static device node
  # loads it on first open, and nothing did: WoW ran on fsync (2026-10-25).
  # The driver creates the node 0666, so no udev rule is needed, and the
  # battlenet and Steam FHS sandboxes dev-bind /dev, so they see it. A switch
  # loads it straight away: systemd-modules-load restarts when the module list
  # changes.
  configurations.nixos.nebula.module = {
    boot.kernelModules = [ "ntsync" ];
  };
}
