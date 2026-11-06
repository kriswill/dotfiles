------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
--
-- WHO OWNS WHAT (2026-11-04). Dux Shell's Settings → Displays owns the
-- monitor setup: position, scale, rotation, mode, VRR, bit depth, colour
-- management. It writes ~/.config/hypr/dms/outputs.lua and runs
-- `hyprctl reload`, and that file is loaded at the bottom of this one. This
-- file adds two things:
--   * BASELINE rules, so the session has a sane layout when Dux's file is
--     absent (fresh home, shell never run, shell disabled) or fails to load.
--   * GUARDS on the OLED against the two settings that blank it (see the
--     notes below): `cm = "auto"` becomes "srgb", and refresh rates above
--     144Hz become 143.97Hz. Everything else Dux writes is kept, including
--     HDR modes like "hdr"/"hdredid", which are cosmetic risks only (washed
--     out), not blanking ones.
--
-- Why filtering is needed: Hyprland keeps one rule per output name, a later
-- rule REPLACES an earlier one whole (CMonitorRuleManager::add), and lookup
-- takes the last match. Dux's rule loaded raw would silently drop anything it
-- doesn't write. Dux's rules are therefore taken only when they use `desc:`
-- (set Displays → "Name format" to **Model**; connector names like DP-3 change
-- across boots here). Connector-named rules and Dux's empty-name catch-all are
-- ignored, so with Name format left at "Name", Dux has no effect and the
-- baseline stands.

local PG348Q = "desc:Ancor Communications Inc ROG PG348Q #ASNtlPMnEjHd"
local PG34WCDM = "desc:ASUSTek COMPUTER INC PG34WCDM RCLMRS022510"

-- Left: ROG PG348Q, portrait (rotated 90° CCW = transform 1), NATIVE scale 1.
-- Logical footprint when rotated: 1440 x 3440.
--
-- Right: PG34WCDM gaming OLED (G-Sync), NATIVE scale 1. XWayland/Proton
-- games can't handle fractional scaling and get broken in-game resolutions; at
-- scale 1 the game sees a true 3440x1440 display, Hyprland can direct-scanout the
-- fullscreen window, and VRR (misc.vrr=2) works natively — no gamescope needed.
-- 3440x1440 on a 34" panel is ~110 PPI, a normal desktop density. Baseline
-- position: right of the portrait (x=1440), y=1581 to match the desk (the
-- cursor crosses where the edges physically meet). Dux's layout overrides it.
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

local baseline = {
  [PG348Q] = { mode = "3440x1440@59.973", transform = 1, scale = 1, position = "0x0" },
  [PG34WCDM] = { mode = "3440x1440@143.97", scale = 1, position = "1440x1581", bitdepth = 10, cm = "srgb" },
}

-- Guards applied to Dux's rules, by output. Dux writes `cm` only when it
-- isn't "auto" and `bitdepth` only when it isn't 8, so a missing field is
-- Dux's default, not "unset".
local OLED_SAFE_MODE = "3440x1440@143.97"
local OLED_MAX_HZ = 144 -- the no-DSC ceiling at 10-bit (see REFRESH RATE above)
local guards = {
  [PG34WCDM] = function(rule)
    if rule.disabled then
      return rule
    end
    if rule.cm == nil or rule.cm == "auto" then
      rule.cm = "srgb"
    end
    -- Any cm beyond srgb needs 10-bit (docs/hdr-hyprland-june-2026.md).
    if rule.cm ~= "srgb" and rule.bitdepth == nil then
      rule.bitdepth = 10
    end
    -- "preferred", "highrr" or a bare WxH resolve to the native 240Hz here.
    local hz = tonumber(tostring(rule.mode or ""):match("^%d+x%d+@([%d.]+)$"))
    if not hz or hz > OLED_MAX_HZ then
      rule.mode = OLED_SAFE_MODE
    end
    return rule
  end,
}

local function merged(rule, extra)
  local out = {}
  for k, v in pairs(rule) do
    out[k] = v
  end
  for k, v in pairs(extra or {}) do
    out[k] = v
  end
  return out
end

for output, rule in pairs(baseline) do
  hl.monitor(merged(rule, { output = output }))
end

-- Dux's rules on top, taken as written (a field Dux omits, e.g. transform
-- after switching rotation back to normal, must NOT fall back to the
-- baseline), then passed through that output's guard.
if package.searchpath("dms.outputs", package.path) then
  local real = hl.monitor
  hl.monitor = function(rule)
    local output = type(rule) == "table" and rule.output or ""
    if type(output) ~= "string" or not output:find("^desc:") then
      return
    end
    local copy = merged(rule)
    real(guards[output] and guards[output](copy) or copy)
  end
  -- pcall: a broken file must not abort the rest of the config or leave
  -- hl.monitor wrapped. Hyprland still shows the load error in its
  -- config-error banner, and the baseline layout stays in effect.
  -- Keep the literal `require("dms.outputs")` call form: Dux's
  -- `dms config resolve-include` only matches that (it follows requires from
  -- hyprland.lua into this file). Otherwise Settings → Displays shows a
  -- "Setup" banner whose fix appends a raw, unguarded require to hyprland.lua.
  pcall(function()
    require("dms.outputs")
  end)
  hl.monitor = real
end
