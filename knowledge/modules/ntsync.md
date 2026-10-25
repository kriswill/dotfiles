---
type: NixOS Module
title: ntsync on nebula
description: 'Loads the kernel''s ntsync driver at boot on nebula (boot.kernelModules), giving Wine and Proton /dev/ntsync, kernel-side NT synchronisation objects that GE-Proton uses instead of fsync whenever the device is there.'
resource: modules/hosts/nebula/ntsync.nix
tags: [nixos-module, host-specific, gaming, wine, proton, kernel]
generated: { by: claude-code/opus-5.5, at: 2026-10-25T15:45:00-07:00 }
sources:
  - id: kernel-ntsync-docs
    resource: https://docs.kernel.org/userspace-api/ntsync.html
    title: 'Linux kernel docs: NT synchronization primitive driver'
  - id: ntsync-driver
    resource: https://github.com/torvalds/linux/blob/master/drivers/misc/ntsync.c
    title: 'drivers/misc/ntsync.c (the misc device, registered with mode 0666)'
  - id: kernelmodules-option-reference
    resource: https://search.nixos.org/options?channel=unstable&show=boot.kernelModules&query=boot.kernelModules
    title: '`boot.kernelModules` option reference'
---

ntsync is a kernel driver that exposes Windows NT synchronisation objects
through `/dev/ntsync` ioctls: semaphores, mutexes, and auto- and
manual-reset events, plus waits on several of them at once.[^kernel-ntsync-docs]
Wine maps its own objects onto them. Without it, Proton approximates the same
semantics with futexes (fsync).

GE-Proton 11 sets `WINENTSYNC=1` by default (`PROTON_NO_NTSYNC=1` opts out),
so it uses the driver whenever it can open the device. The wineserver reports
which one it got: `ntsync: up and running.` or `fsync: up and running.`. On
2026-10-25 a logged WoW session ([battlenet](../packages/battlenet.md)) still
ran on fsync. nebula's kernel builds the driver as a module
(`CONFIG_NTSYNC=m`), and nothing had loaded it.

Wiring: `boot.kernelModules = [ "ntsync" ]`.[^kernelmodules-option-reference]
Gotchas:

- **Nothing loads it on demand.** The driver registers a dynamic minor, so
  there's no static device node to trigger autoloading on first open.
- **No udev rule needed.** The driver creates the node `0666`, so any user
  can open it.[^ntsync-driver]
- **The sandboxes see it.** The battlenet and Steam FHS sandboxes dev-bind
  `/dev`.
- **No reboot needed.** systemd-modules-load restarts when the module list
  changes, so a switch loads it straight away.

Verified on generation 184 (2026-10-25):

- The switch started `systemd-modules-load`, and `/dev/ntsync` appeared as
  `crw-rw-rw- root root 10, 261`.
- Battle.net's wineserver printed `ntsync: up and running.`
- Every ntsync object is a file descriptor. The wineserver held about 5,000
  of them, and WoW held 101 of its 898.
- The limits leave plenty of room. Wine raises its soft `RLIMIT_NOFILE` to
  the hard limit (524,288), so the wineserver and every Wine process run at
  524,288, while the launcher's own Python stays at 1,024.

Host-specific file for [nebula](../hosts/nebula.md), merged straight into
that host's configuration per the
[host-mounted modules pattern](../patterns/host-mounted-modules.md).
Related: [nebula-battlenet](nebula-battlenet.md).

## Source

- Module: [`modules/hosts/nebula/ntsync.nix`](../../modules/hosts/nebula/ntsync.nix)

[^kernel-ntsync-docs]: Linux kernel docs: NT synchronization primitive driver (objects, ioctls)
[^ntsync-driver]: `drivers/misc/ntsync.c`: `ntsync_misc` with `.mode = 0666`
[^kernelmodules-option-reference]: `boot.kernelModules` option reference
