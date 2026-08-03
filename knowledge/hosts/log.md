# Log

## 2026-08-02

- **Addition** — [nebula](nebula.md):
  `modules/hosts/nebula/herdr-update-check.nix`, a daily systemd user timer
  that fetches herdr's version from nixos-unstable (one raw-GitHub fetch) and
  pops a dismissable notification (action → upstream releases page) once it
  exceeds the pinned 0.7.5 — the prompt to drop the herdr preview-flake pin
  ([herdr module](../modules/herdr.md)). Deliberately temporary: the file is
  deleted together with the pin.

## 2026-07-03

- **Update** — [nebula](nebula.md) gained a "Firmware quirks" section:
  the warm-reboot DRAM-training hang (debug code 44 + yellow DRAM LED on BIOS
  `2.A02`; userspace shutdown was clean, the firmware stalled re-training DDR5
  — cold cycle clears it; fix = BIOS update past `2.A02` or Memory Context
  Restore), plus the standing `Wake Up Event By = OS` suspend fact with the
  reminder that a BIOS flash resets it.
