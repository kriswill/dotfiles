------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
--
-- Hyprland owns the monitor layout in this session. Both monitors are described
-- in full here, matched by stable description (DP-* connector numbers aren't
-- stable across boots). The OLED is forced to native scale 1 (see below).

-- Left: ROG PG348Q, portrait (rotated 90° CCW = transform 1), NATIVE scale 1.
-- Logical footprint when rotated: 1440 x 3440.
hl.monitor({
  output = "desc:Ancor Communications Inc ROG PG348Q #ASNtlPMnEjHd",
  mode = "3440x1440@59.973",
  transform = 1,
  scale = 1,
  position = "0x0",
})

-- Right: PG34WCDM gaming OLED (G-Sync), NATIVE scale 1. XWayland/Proton
-- games can't handle fractional scaling and get broken in-game resolutions; at
-- scale 1 the game sees a true 3440x1440 display, Hyprland can direct-scanout the
-- fullscreen window, and VRR (misc.vrr=2) works natively — no gamescope needed.
-- 3440x1440 on a 34" panel is ~110 PPI, a normal desktop density. Positioned to
-- the right of the portrait monitor (x=1440) and vertically centred against it
-- ((3440-1440)/2 = 1000).
--
-- REFRESH RATE — 143.97Hz, NOT the panel's native 240Hz (changed 2026-06-16).
-- The PG34WCDM is a DP 1.4 panel (HBR3, ~25.9 Gbit/s usable; the RTX 5080 can't go
-- faster because the *monitor* caps the link). 3440x1440@240 needs ~28-36 Gbit/s
-- so it REQUIRES DSC — and DSC does not negotiate under the current NVIDIA driver
-- (595.80, open modules), so @240 trains no link at all: the OLED shows "no
-- DisplayPort signal" while Hyprland still reports the output enabled+dpms-on.
-- That was the "blank OLED at login" bug — the saved config asked for an
-- untrainable mode. 143.97Hz @ 10-bit ≈ 21.4 Gbit/s fits HBR3 WITHOUT DSC, so it
-- trains reliably and is the highest refresh that still keeps 10-bit/HDR. (No-DSC
-- ceilings: ~180Hz @ 8-bit, ~143Hz @ 10-bit, 120Hz comfortably @ 10-bit. True
-- 240Hz is only possible if DSC starts working.) Verified live 2026-06-16.
--
-- CM: "srgb", NOT "auto" (changed 2026-07-21). cm "auto" turned the OLED OFF
-- whenever a fullscreen video played in Helium: Chromium's
-- wp_color_management_v1 usage made "auto" attempt the PQ/HDR mode flip, and the
-- resulting modeset dropped the DP link (same Blackwell atomic-test failure class
-- as the 240Hz blank above). Even plain SDR bt709 video triggered it, and
-- Helium's force-color-profile=srgb flag did NOT prevent it — the protocol-level
-- poke happens regardless. "srgb" keeps the 10-bit wide-SDR desktop and can never
-- mode-switch. Cost: no HDR pipeline on this output — acceptable since nothing
-- uses HDR today (WoW launches SDR; see docs/hdr-hyprland-june-2026.md). If HDR
-- gaming ever lands, re-test cm "auto" on a newer driver, knowing fullscreen
-- browser video is the repro. cm "hdr" (whole desktop HDR) was already ruled out
-- as washed-out for SDR content.
hl.monitor({
  output = "desc:ASUSTek COMPUTER INC PG34WCDM RCLMRS022510",
  mode = "3440x1440@143.97",
  scale = 1,
  position = "1440x1000",
  bitdepth = 10,
  cm = "srgb",
})
