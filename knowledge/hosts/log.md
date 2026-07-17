# Log

## 2026-07-03

- **Update** — [nebula](nebula.md) gained a "Firmware quirks" section:
  the warm-reboot DRAM-training hang (debug code 44 + yellow DRAM LED on BIOS
  `2.A02`; userspace shutdown was clean, the firmware stalled re-training DDR5
  — cold cycle clears it; fix = BIOS update past `2.A02` or Memory Context
  Restore), plus the standing `Wake Up Event By = OS` suspend fact with the
  reminder that a BIOS flash resets it.
