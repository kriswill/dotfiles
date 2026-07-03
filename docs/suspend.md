# Suspend / sleep on nebula

**Verified against:** nebula — MSI MAG X870E TOMAHAWK WIFI (MS-7E59), BIOS
`2.A02` (2025-07-30), AMD CPU + NVIDIA GPU. Sleep state in use: **`deep`
(S3)**. Checked 2026-06-22.

## State

- `cat /sys/power/mem_sleep` → `s2idle [deep]` — `deep`/S3 is the default and
  what we use (true power-down: fans off, RGB off, peripherals unpowered).
- Suspend is wired through systemd/logind; the desktop shell (noctalia) "lock
  and suspend" just calls the normal logind suspend path.
- Wake source: **keyboard only** (mouse does not wake it) — this is the Linux
  default once the BIOS hands wake control to the OS (see below). The Wooting
  80HE keyboard (`/sys/bus/usb/devices/3-1`) has `power/wakeup = enabled`.

## The one BIOS setting that matters

`Settings ▸ Advanced ▸ Wake Up Event Setup ▸ Wake Up Event By` **must be `OS`,
not `BIOS`.**

When set to `BIOS`, the firmware owns all wake decisions and **overrides every
Linux wakeup control** — `/sys/.../power/wakeup` toggles, GPE masks, the lot.
On this board that mode also asserted a wake the instant S3 was entered, so the
machine woke ~1 second after suspending, every time. Setting it to `OS` hands
wake control to Linux, whose defaults wake on keyboard but not mouse, and S3
then sleeps correctly.

No NixOS/flake config is involved — `deep` is the kernel default and the
`Wake Up Event By` choice persists in BIOS NVRAM.

## Diagnosing a wake problem

```sh
# What woke it / sleep cycle in the kernel log
journalctl -k -b -g 'Waking up|suspend entry|suspend exit|PME|xHC|wakeup'

# Devices currently armed to wake the system
for f in $(find /sys/devices -path '*/power/wakeup'); do \
  [ "$(cat "$f")" = enabled ] && echo "$f"; done

# Per-source wake attribution (count >0 = it fired)
for d in /sys/class/wakeup/*/; do c=$(cat "$d/wakeup_count"); \
  [ "${c:-0}" -gt 0 ] && echo "$c $(cat "$d/name")"; done | sort -rn

# ACPI GPE fire counts (the numbered files are hex GPE IDs)
grep -i enabled /sys/firmware/acpi/interrupts/* | grep -vE ':\s+0\s'

# RTC wake alarm — should be EMPTY
cat /sys/class/rtc/rtc0/wakealarm
```

Runtime knobs (all reset on reboot, so safe to experiment):

```sh
echo disabled | sudo tee /sys/bus/pci/devices/<BDF>/power/wakeup   # gate one device
echo disable  | sudo tee /sys/firmware/acpi/interrupts/gpeNN       # mask a GPE
echo s2idle   | sudo tee /sys/power/mem_sleep                      # switch sleep path
```

## Learned behaviours & workarounds

- **(2026-06-22) Immediate wake from S3 was a BIOS setting, not a Linux
  problem.** With `Wake Up Event By = BIOS`, *nothing* on the Linux side has any
  effect — we disabled the keyboard's `power/wakeup`, masked GPEs `gpe04`/`gpe10`/
  `gpe1B`, disabled wakeup on PCIe port `00:02.2` and on the xHCI controllers
  `0000:11:00.0` / `0000:13:00.0`, and it still woke every cycle. The fix was
  flipping that one BIOS option to `OS`. **If sleep misbehaves, check this BIOS
  setting before touching anything in Linux.**
- **`xhci_hcd 0000:13:00.0 / 0000:11:00.0: xHC error in resume, USBSTS 0x401,
  Reinit`** appears in the log on *every* resume. It looked like the smoking gun
  (present in 100% of failed cycles) but was a red herring — it persists on
  successful resumes too. Don't chase it.
- **`pcieport 0000:00:02.2: PME: Spurious native interrupt!`** is intermittent
  noise (fires on only some cycles, even with that port's wakeup disabled), not a
  wake cause. `00:02.2` heads the USB4/Thunderbolt subtree.
- **`s2idle` "works" but isn't real sleep.** It stays asleep and the keyboard
  wakes it, but being suspend-to-idle the board stays in S0 — **fans and RGB stay
  on**, near-zero power saving. Only useful as a fallback if S3 can't be fixed.
  To make it permanent: `boot.kernelParams = [ "mem_sleep_default=s2idle" ]`.
- **Mouse does not wake the machine; keyboard does.** That's the Linux default
  with OS-controlled wake — no extra config needed.

## Sources

- Live machine: `journalctl -k`, `/sys/power/mem_sleep`,
  `/sys/.../power/wakeup`, `/sys/firmware/acpi/interrupts/`, `/sys/class/dmi/id/`
  (2026-06-22).
- MSI Click BIOS (X870E), `Settings ▸ Advanced ▸ Wake Up Event Setup`.
- Kernel docs: `Documentation/admin-guide/pm/sleep-states.rst` (S3 vs s2idle).
