# HDR on nebula: status as of June 2026

Findings from investigating how to get HDR working on the OLED monitor
(ASUS PG34WCDM) under niri, researched 2026-06-12.

## Hardware / software at time of writing

| Component | Value |
|---|---|
| OLED monitor | ASUS PG34WCDM, 3440x1440 @ 240 Hz (kanshi profile `home`, right output) |
| Second monitor | ASUS ROG PG348Q, 3440x1440 @ 60 Hz, portrait |
| GPU | NVIDIA GeForce RTX 5080 |
| NVIDIA driver | 595.45.04 |
| Compositor | niri 26.04 (nixpkgs, via snowglobe-lib `desktop.niri`) |

The GPU and driver are fully HDR-capable. The monitor does HDR fine (verified
on the Windows partition, which has an HDR profile plus an NVIDIA-app per-app
OC profile). **The only blocker is the compositor.**

## Why HDR doesn't work under niri

HDR on Wayland requires the compositor to implement the color-management
protocol (`wp_color_management_v1`). niri — including 26.04 — does not.
There is no `hdr` option in `config.kdl` and kanshi can't set it either;
niri deliberately forces outputs to SDR so an HDR mode left enabled by
another OS/compositor doesn't render with broken colors
([niri #1841](https://github.com/YaLTeR/niri/issues/1841)).

It is not coming soon:

- The maintainer's plan is to build on Smithay's color-management work
  ([niri discussion #1128](https://github.com/YaLTeR/niri/discussions/1128)).
- That upstream PR, [Smithay #1143](https://github.com/Smithay/smithay/pull/1143),
  was still an **untested draft** as of 2026-06-12 — protocol plumbing only,
  no color-aware rendering pipeline behind it, ~3 years in progress.
- Realistic estimate: a year or more before niri ships HDR.

## Options

### 1. Second session with KDE Plasma 6 (recommended)

KWin has the most mature HDR-on-NVIDIA support of any Wayland compositor:
per-monitor HDR toggle in Display settings, brightness/calibration controls,
works well with driver 555+. Coexists with the niri session; pick at login.

```nix
# host config
services.desktopManager.plasma6.enable = true;
```

- HDR games there: `gamescope --hdr-enabled -- %command%` (nested) or Proton
  HDR env vars.
- HDR video: mpv with `target-colorspace-hint=yes`.
- Redo HDR calibration with Plasma's own wizard — the Windows profile does
  not transfer (it lives in Windows' color pipeline, not the monitor).

### 2. Standalone gamescope session (games only)

Gamescope as its own DRM session (from a TTY or a dedicated login entry,
*not* nested inside niri) can do HDR with `--hdr-enabled` and Steam inside.
Works on NVIDIA with recent drivers but is the finicky path — gamescope is
primarily developed against AMD/Steam Deck.

### 3. Wait for niri

Watch [niri discussion #1128](https://github.com/YaLTeR/niri/discussions/1128).
Nothing to configure until Smithay lands color management.

## Related: GPU overclocking parity with Windows

The Linux equivalent of the NVIDIA app's OC profile is
[LACT](https://github.com/ilya-zlobintsev/LACT) — supports clock/power
offsets on RTX cards with this driver generation. Packaged in nixpkgs
(`lact` + daemon).

## Sources

- [HDR Support? — niri discussion #1128](https://github.com/YaLTeR/niri/discussions/1128)
- [Wrong colors on HDR monitor — niri #1841](https://github.com/YaLTeR/niri/issues/1841)
- [Smithay color-management PR #1143](https://github.com/Smithay/smithay/pull/1143)
- [niri 26.04 release coverage (Phoronix)](https://www.phoronix.com/news/Niri-26.04-Released)
- [niri 25.08 release notes](https://newreleases.io/project/github/niri-wm/niri/release/v25.08)
