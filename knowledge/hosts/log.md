# Log

## 2026-10-25

- **Update**: [nebula](nebula.md) turns off VLC (snowglobe's desktop layer)
  and Tor Browser (its hacker-mode profile; the tor daemon stays). They were
  the only things pulling in ffmpeg 7.1.5 (41 nixploit findings, see
  [nebula-nixploit](../modules/nebula-nixploit.md)). The closure drops by
  about 550 MiB.
- **Update**: [nebula](nebula.md) turns off Lutris
  (`programs.lutris.enable = false`, overriding snowglobe's gaming profile).
  Its FHS runtime was the only thing pulling in ffmpeg 6.1.6 (39 nixploit
  findings, see
  [nebula-nixploit](../modules/nebula-nixploit.md)). The closure drops by
  about 900 MiB.

## 2026-10-14

- **Update** — [k](k.md): installs P4V, P4Admin and P4Merge 2026.3 through
  `environment.systemPackages` (`/Applications/Nix Apps`, Spotlight-indexed),
  replacing the drag-installed DMG copies
  ([decision](../decisions/p4v-nix-apps-dont-strip.md)).

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
