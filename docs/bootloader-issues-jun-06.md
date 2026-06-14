# nebula boot failures — diagnosis (2026-06-06)

A day of rapid rebuilds ended with **newly built generations refusing to boot**:
the machine would drop to a kernel panic or systemd emergency, and the only way
back in was to pick an old generation from the boot menu. This is the writeup of
how the problem was diagnosed — including the wrong turns — because the path to
the answer is the useful part.

There turned out to be **two independent bugs** wearing each other's clothes:

| # | Bug | Nature | Fix |
|---|-----|--------|-----|
| 1 | A custom activation script called `exit 0`, aborting boot-time activation | **Deterministic**, every gen from #13 on, identical under any bootloader | Confine `exit`/`set -u` to a subshell (`libreoffice-paths.nix`, `dotfiles-stow.nix`) |
| 2 | GRUB intermittently failed to read the initrd from the ESP | **Intermittent**, any gen, GRUB-specific | Briefly moved to systemd-boot to prove it; later returned to GRUB |

Bug #1 was the real cause of "new generations won't boot." Bug #2 was a separate,
rarer fault that muddied the picture for a while.

Host: `nebula` — MSI MAG X870E TOMAHAWK WIFI (AMI UEFI), AMD + NVIDIA, two NVMe
drives (NixOS on a Samsung SSD 9100 PRO 4 TB; Windows on a separate disk),
`nixos-rebuild-ng`, GRUB via `snowglobe-lib`, `harden` profile enabled.

---

## Symptoms

- After `sudo nixos-rebuild switch` / `snowglobe-rebuild switch`, the rebuild
  appeared to succeed, but on reboot the machine did **not** come up on the new
  generation. The user had to manually select an older generation from GRUB.
- Booting recent generations showed one of:
  - a **kernel panic**: `VFS: Unable to mount root fs on "fstab" ...` with an
    **empty** `List of all partitions:`; or
  - `[!!!!!!] Switch root target contains no usable init.`; or
  - systemd **emergency mode**, which was a dead end because the `harden` profile
    locks the root account ("root account is locked / no valid config").

Initial (incorrect) framing: "the switch is broken — maybe the recent sudo→1Password
PAM work did it."

---

## How it was diagnosed

### 1. Establish what actually still works

Rather than trust the framing, confirm each stage of `nixos-rebuild` independently:

```sh
# The system profile IS being updated...
readlink /nix/var/nix/profiles/system          # -> system-21-link (the new gen)
# ...but the RUNNING system is an older generation:
readlink -f /run/current-system                 # -> gen-10 store path
```

`journalctl` showed `switch-to-configuration switch` **completing** for the newest
generation and the profile being set. So build, activation, and profile-linking
all worked. What didn't: the machine booted an *old* generation. That reframed the
question from "the switch is broken" to "the new generation won't boot."

### 2. Rule out the cheap explanations

| Check | Command | Result |
|-------|---------|--------|
| ESP full? | `df -h /boot` | 12 % used — no |
| Disk dying? | `smartctl -H /dev/nvme1n1` | `PASSED`, no errors |
| initrd truncated on ESP? | compare `/boot/kernels/*-initrd` size vs `/nix/store/...` | byte-identical |
| Bootloader type | `INSTALL_BOOTLOADER` in `…/bin/switch-to-configuration` | GRUB |

### 3. Read the panic literally

The first decisive clue was the kernel panic text. `List of all partitions:`
being **empty** means the kernel saw **zero block devices** — which happens when
it boots **without an initramfs** (the `nvme` driver lives in
`boot.initrd.availableKernelModules`, so no initrd ⇒ no disks ⇒ can't mount root).

So that particular failure was "the initrd never loaded," which is a
**bootloader/firmware** problem, not a NixOS config problem.

### 4. The "identical files, different outcome" tell

The ESP held exactly **one** kernel and **one** initrd (all generations share the
same hash). `grub.cfg` proved every generation pointed at the *same* `bzImage` and
the *same* initrd — entries differed only by the `init=` path:

```
linux  ($drive1)//kernels/k3c378…-bzImage  init=/nix/store/<gen>/init root=fstab …
initrd ($drive1)//kernels/jjjl7slf…-initrd
```

Same kernel + same initrd + healthy disk + intact files, yet gen 10 booted and
gen 15 panicked. That is the signature of an **intermittent ESP read failure** —
GRUB on UEFI uses its *own* reimplemented NVMe + FAT drivers, and on this firmware
the larger (28 MB) initrd read sometimes failed while the 13 MB kernel succeeded.
GRUB then booted the kernel with no initrd → panic.

### 5. First fix attempt: systemd-boot (a partial answer)

To remove GRUB's fragile read path, the host was switched to systemd-boot, which
delegates kernel/initrd loading to the firmware. After fighting MSI's firmware
(it ignores `efibootmgr` `BootOrder` and re-prefers its own named entry; the GRUB
NVRAM entry had to be deleted for systemd-boot to win), the machine finally booted
**systemd-boot** — and gens 10–12 booted reliably.

**But the latest generation still failed in exactly the same way.**

### 6. The key insight: same error under *both* bootloaders

The breakthrough was the observation that the failure reproduced **identically
under systemd-boot and GRUB**. If swapping the bootloader changes nothing, the
bootloader is not the cause. That pointed the investigation at the *configuration*
and the right question: **what changed between the last bootable generation and the
first broken one?**

### 7. Closure-diff the boundary (gen 12 = last good, gen 13 = first bad)

Diff the two system closures directly — this captures the *effective* config,
including states that were never committed:

```sh
G12=$(readlink -f /nix/var/nix/profiles/system-12-link)
G13=$(readlink -f /nix/var/nix/profiles/system-13-link)
diff -rq "$G12" "$G13"
```

Findings:
- `init`, `kernel`, kernel-params, and the whole systemd unit tree: **identical**.
- The real delta was the **LibreOffice modules**: a new `libreofficePaths`
  activation snippet, plus `GTK_THEME` env (dark theme) and some tmpfiles dirs.
- Earlier suspicion of `sudo-1password.nix` was **wrong** — its PAM/sudoers/env
  changes are boot-inert and, crucially, landed in a *later* generation. The
  gen-12→13 env change was just `GTK_THEME="Adwaita:dark"`.

### 8. Find the mechanism, then prove it

The `activate` script (concatenation of all `system.activationScripts`) had gained:

```sh
#### Activation script snippet libreofficePaths:
set -u
...
  exit 0          # ← on virtually every boot path
```

NixOS runs **all** activation snippets in **one shell**. A bare `exit` doesn't end
*that snippet* — it **terminates the entire activation**, skipping every snippet
ordered after it. The proof is the very last line of `activate`:

```sh
ln -sfn "$(readlink -f "$systemConfig")" /run/current-system
exit $_status
```

The early `exit 0` aborted activation **before `/run/current-system` was ever
created**, so a fresh boot could not finish coming up. It went unnoticed during
`nixos-rebuild switch` because the box was *already running* — incomplete
re-activation is invisible until the next cold boot. That is exactly why the bug
appeared "on reboot" and was deterministic and bootloader-independent.

---

## Root causes & fixes

### Bug 1 — activation `exit 0` (the real culprit)

`modules/nixos/libreoffice-paths.nix` used `set -u` and `exit 0` at the top
level of its activation snippet. Fix: wrap the body in a subshell so `exit`/`set -u`
are confined to that snippet and can't abort or alter the rest of activation:

```nix
text = ''
  # Activation snippets are concatenated into ONE script run in a single shell;
  # a bare `exit` aborts the whole activation (breaking boot) and `set -u` leaks.
  (
  set -u
  ...
  )
'';
```

`modules/nixos/dotfiles-stow.nix` had the same pattern (its `exit 0` only
fires if the stow dir is missing — a *latent* version of the bug); it was wrapped
the same way. Verified with `bash -n` on the generated `activate` and a rebuild.

> **Rule:** never use `exit`, `set -e`, or `set -u` at the top level of a NixOS
> activation snippet. Use control flow, or wrap the body in `( … )`.

### Bug 2 — GRUB intermittent initrd read

GRUB on this firmware intermittently failed to read the 28 MB initrd from the ESP,
booting the kernel with no initramfs. systemd-boot (firmware-driven loading) avoids
this class of fault and proved the failure was real and separate.

---

## Final decision: back to GRUB (for dual boot)

After Bug 1 was fixed, the host was **returned to GRUB**, on purpose: the goal is a
boot menu that also offers **Windows**, which lives on a *separate disk/ESP*.
systemd-boot only surfaces entries on its own ESP, so it would not list that
Windows install; GRUB with **os-prober** scans all disks and adds it. Enabled via:

```nix
# modules/hosts/_nebula/configuration.nix
boot.loader.grub.useOSProber = true;
```

Migration steps that were needed (one-time):

```sh
# reinstall GRUB + recreate its EFI entry (required when migrating bootloaders)
sudo nixos-rebuild boot --flake .#nebula --install-bootloader
sudo bootctl remove                       # uninstall systemd-boot from the ESP
sudo efibootmgr -b 0002 -B                # delete leftover "Linux Boot Manager"
sudo efibootmgr -b 0008 -B                # delete leftover "UEFI OS" (fallback)
```

(MSI firmware ignores `BootOrder`, so the competing NVRAM entry must be *deleted*,
not just reordered.) Result: GRUB boots, lists NixOS generations + Windows, and
gen 25 came up cleanly.

---

## Lessons

- **Don't trust the framing; verify each stage.** "The switch is broken" was false —
  build/activate/profile all worked; only the cold boot failed.
- **Read panic text literally.** "empty `List of all partitions:`" = no initrd =
  bootloader/firmware, not config.
- **Closure-diff adjacent generations** (`diff -rq` on the two `/run/.../system-*`
  store paths) to find the *effective* change — including uncommitted states — far
  more reliably than reading git history.
- **"Same failure regardless of bootloader" ⇒ the bootloader isn't the cause.**
  This single observation redirected the whole investigation correctly.
- **Activation snippets share one shell** — `exit`/`set -u`/`set -e` leak. The
  failure mode (incomplete activation) is invisible on `switch` and only bites on a
  cold boot.
- **`harden` locks root**, making emergency mode unusable for debugging. Add
  `systemd.debug-shell=1` to a boot entry for a passwordless tty9 shell when a boot
  wedges.
- **`nix` flake eval ignores untracked files** — `git add` new host files before
  `nixos-rebuild` (the `snowglobe-rebuild` wrapper does `git add .` for you).
- Generations 13–22 are **permanently unbootable**: the broken activation is baked
  into their immutable closures. Only generations rebuilt after the fix boot.
