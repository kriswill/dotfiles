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
-- HDR: bitdepth 10 + cm "auto" (verified 2026-06-13, Hyprland 0.55). "auto" keeps
-- the SDR desktop in proper SDR (preset reports "wide" — 10-bit wide-gamut SDR) and
-- only flips the output to the full HDR/PQ pipeline (preset "hdr") when a client
-- presents HDR content. cm "hdr" (force whole desktop HDR) looked washed out for
-- everyday SDR content even with sdrbrightness/sdrsaturation tuning, so "auto" is
-- the right default for a mixed desktop+gaming OLED. NOTE: a client must speak the
-- wp_color_management_v1 protocol to trigger HDR — plain XWayland (how the WoW rule
-- below runs today) does NOT, so HDR games need PROTON_ENABLE_WAYLAND=1 DXVK_HDR=1
-- (native Wayland) or gamescope --hdr-enabled. See docs/hdr-hyprland-june-2026.md.
hl.monitor({
  output = "desc:ASUSTek COMPUTER INC PG34WCDM RCLMRS022510",
  mode = "3440x1440@143.97",
  scale = 1,
  position = "1440x1000",
  bitdepth = 10,
  cm = "auto",
})
