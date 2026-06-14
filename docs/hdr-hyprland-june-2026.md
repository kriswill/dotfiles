# HDR on nebula under Hyprland: status as of June 2026

How HDR works on the OLED monitor under **Hyprland 0.55**, verified on nebula
2026-06-13. This supersedes the niri-era finding that "the compositor is the
blocker" — see [`hdr-niri-june-2026.md`](hdr-niri-june-2026.md), which is now
historical (it applies only to the niri session).

## Verified state (2026-06-13)

| Component | Value |
|---|---|
| Compositor | Hyprland 0.55.0 (`f719bd6`) |
| OLED monitor | ASUS PG34WCDM, connector **DP-3**, `desc:ASUSTek COMPUTER INC PG34WCDM RCLMRS022510`, 3440x1440@240 |
| Second monitor | ASUS ROG PG348Q, **DP-1**, portrait, SDR (left untouched) |
| GPU / driver | NVIDIA RTX 5080 / 595.45.04 |
| Color mgmt | `render:cm_enabled = true` — Hyprland advertises `wp_color_management_v1` to clients (no experimental flag needed in 0.55) |

Unlike niri (no color-management protocol at all), **Hyprland supports HDR.**

## How to tell if the compositor is outputting HDR

`hyprctl monitors` is authoritative. Per output, look at:

- **`currentFormat`** — `XRGB8888` = 8-bit SDR; `XBGR2101010`/`XRGB2101010`
  (logged by aquamarine as `XB30`) = 10-bit, the prerequisite for HDR.
- **`colorManagementPreset`** — `srgb` (plain SDR), `wide` (10-bit wide-gamut
  SDR), or `hdr` (full HDR/PQ pipeline active).
- `sdrBrightness` / `sdrSaturation` / `sdrMinLuminance` / `sdrMaxLuminance` —
  the live SDR-mapping knobs (see tuning below).

```sh
hyprctl -j monitors | jq -r '.[] | "\(.name): \(.currentFormat) preset=\(.colorManagementPreset)"'
```

> `supportsHdr` / `supportsWideColor` read `null` on this NVIDIA setup even when
> HDR works — that introspection field isn't populated. Trust `currentFormat` +
> `colorManagementPreset`, not those.

## Monitor config (what's in `hyprland.lua`)

```lua
hl.monitor({
    output = "desc:ASUSTek COMPUTER INC PG34WCDM RCLMRS022510",
    mode = "3440x1440@239.984", scale = 1, position = "900x355",
    bitdepth = 10,
    cm = "auto",
})
```

- **`cm = "auto"` is the chosen default.** It keeps the SDR desktop in proper
  SDR (preset reports `wide`) and only flips the *whole output* to the HDR/PQ
  curve (preset `hdr`) when a client presents HDR content. For a mixed
  desktop+gaming OLED this is the right mode.
- **`cm = "hdr"` (force whole desktop into HDR) looked washed out** for everyday
  SDR content — milky blacks, pale colors — even after tuning `sdrbrightness`
  (tried 1.2) and `sdrsaturation`. Forcing desktop HDR is not recommended here.
- `bitdepth = 10` is required for any `cm` mode beyond `srgb`.

### `cm` values

`auto` (content-driven, recommended), `srgb`, `wide` (10-bit wide gamut, SDR
transfer), `hdr` (force PQ), `hdredid` (HDR using EDID luminance), `edid`.

### Live tuning without editing the config

The Lua parser rejects `hyprctl keyword monitor …` ("keyword can't work with
non-legacy parsers. Use eval."). Apply changes live — instant, reverts on
`hyprctl reload` — with `hyprctl eval` and a full `hl.monitor{}` call:

```sh
hyprctl eval 'hl.monitor({ output = "desc:ASUSTek COMPUTER INC PG34WCDM RCLMRS022510", mode = "3440x1440@239.984", scale = 1, position = "900x355", bitdepth = 10, cm = "auto", sdrbrightness = 1.0, sdrsaturation = 1.0 })'
```

If you do run `cm = "hdr"` and need to de-washout SDR content, the knobs are
`sdrbrightness` (white-level multiplier), `sdrsaturation`, and the luminance
floor/ceiling. Gamma tools (`gammastep`/`wlsunset`/`wl-gammarelay`) are the
**wrong layer** — they drive `wlr-gamma-control` and fight the cm pipeline;
none are installed. Full colorimeter calibration (DisplayCAL/colord) is overkill
and immature on Wayland HDR.

## Getting *games* into HDR (the client side)

`cm = "auto"` only lets the compositor *accept* HDR; the client must speak
`wp_color_management_v1` to trigger it. **Plain XWayland does not** — and WoW
currently runs as a native XWayland Proton fullscreen window (the
`wow-fullscreen` window rule + native-scale monitor setup, chosen for direct
scanout + VRR without gamescope). So as launched today, WoW stays SDR.

Two ways to give a Proton game an HDR path (set in Steam → launch options;
in-game HDR toggle must also be on):

1. **Proton native Wayland (keeps the no-gamescope / VRR / direct-scanout setup):**
   ```
   PROTON_ENABLE_WAYLAND=1 PROTON_ENABLE_HDR=1 DXVK_HDR=1 %command%
   ```
   DXVK gets an HDR Vulkan swapchain straight from Hyprland's color management —
   no XWayland, no gamescope. Newer/less battle-tested but most aligned with this
   host's config.

   **WoW specifics (verified-as-launched 2026-06-13):** WoW runs through the
   **Battle.net launcher** under **Proton 11.0** (Steam AppId `3862034770`). Set
   the launch options on that Steam entry, then **fully quit Battle.net and
   relaunch** — env attaches only at prefix startup, so an already-running
   launcher won't pick it up. The make-or-break check is `hyprctl activewindow`
   showing the WoW window as **`xwayland=false`**; if it's still `xwayland=true`,
   Proton stayed on the X11 backend and HDR cannot engage (XWayland carries no
   color management).

   **ROOT CAUSE found 2026-06-13: the Proton build must ship `winewayland.drv`.**
   With the vars correctly set on `WoW.exe` (confirmed via `/proc/<pid>/environ`)
   but running under **stable Proton 11.0**, the window stayed `xwayland=true`
   and `winex11.drv` was mapped — because **Proton 11.0 ships no
   `winewayland.drv`** (only `winex11.drv` exists under
   `…/Proton 11.0/files/lib/wine/`). `PROTON_ENABLE_WAYLAND=1` is then a silent
   no-op. **`GE-Proton10-34`** (in `~/.local/share/Steam/compatibilitytools.d/`)
   *does* ship `winewayland.drv`, so force that compat tool for WoW (Steam →
   Properties → Compatibility), keep the launch options, fully quit Battle.net,
   relaunch. Audit which installed builds have the driver:
   ```sh
   for d in ~/.local/share/Steam/steamapps/common/Proton* ~/.local/share/Steam/compatibilitytools.d/*; do
     find "$d/files/lib/wine" -name winewayland.drv -printf "%h has wayland driver\n" 2>/dev/null
   done
   ```
   Confirm the live driver in a running game:
   `grep -oE 'wine(wayland|x11)\.drv' /proc/<pid>/maps`.

   **OUTCOME 2026-06-13: native-Wayland HDR abandoned for WoW — the Battle.net
   launcher hangs under `winewayland.drv`.** Forcing GE-Proton10-34 +
   `PROTON_ENABLE_WAYLAND=1` got the prefix onto the Wayland driver, but the
   Battle.net launcher (Chromium/CEF UI) froze at the login panel — a known
   `winewayland.drv` limitation with Chromium-based launchers. Since WoW is only
   reachable *through* that launcher, Route 1 is a dead end for this game. Kill a
   wedged prefix with `WINEPREFIX=<pfx> <proton>/files/bin/wineserver -k`.
   **Decision: reverted WoW to stable Proton 11.0 with launch options cleared
   (back to native-XWayland + VRR + direct-scanout, SDR).** The desktop
   `cm = "auto"` config is unaffected. The only remaining game-HDR option is the
   gamescope route (Route 2) — not pursued, to avoid reintroducing nested judder.

2. **gamescope (battle-tested, but reintroduces nesting):**
   ```
   gamescope -W 3440 -H 1440 -r 240 --hdr-enabled --adaptive-sync -f -- %command%
   ```
   plus `DXVK_HDR=1`. Reliable HDR, but this is the nested setup the monitor
   comment moved *away* from (judder). `gamescope` is installed.

To confirm a game actually went HDR: while it's running fullscreen,
`hyprctl monitors` for DP-3 should show `colorManagementPreset=hdr`. HDR video
also works via `mpv --target-colorspace-hint=yes`.

## Learned behaviours & workarounds

- **`hyprctl keyword monitor` fails under the Lua parser** — use
  `hyprctl eval 'hl.monitor{...}'` for live monitor changes (2026-06-13).
- **`HYPRLAND_INSTANCE_SIGNATURE` goes stale across restarts** — multiple
  instance dirs accumulate under `/run/user/1000/hypr/`, and a dead one lacks
  `.socket.sock` (only `.socket2.sock` remains), so `hyprctl` errors with
  "Couldn't connect … (4)". Pick the dir whose `.socket.sock` exists, or loop
  over them testing `hyprctl version` (2026-06-13).
- **`supportsHdr` is `null`, not `false`, on NVIDIA** even when HDR works —
  ignore it; read `currentFormat`/`colorManagementPreset` (2026-06-13).
- **Live format switch logs transient errors** — `Failed acquiring a buffer` /
  `Cannot commit when a page-flip is awaiting` from aquamarine during the
  modeset; they settle once the swapchain reconfigures to `XB30` (2026-06-13).
- **10-bit caveats** (from `hyprland.md`): window border gradients aren't true
  10-bit, and some apps can't screen-capture while the output is 10-bit.

## Sources

- [Hyprland — Color Management & HDR wiki](https://wiki.hypr.land/Configuring/HDR/)
- [Hyprland Monitors wiki](https://wiki.hypr.land/Configuring/Monitors/)
- Machine-verified on nebula via `hyprctl monitors` / `hyprctl eval`, 2026-06-13.
