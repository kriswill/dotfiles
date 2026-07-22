# HDR on nebula under Hyprland: status as of June 2026

How HDR works on the OLED monitor under **Hyprland 0.55**, verified on nebula
2026-06-13. This supersedes the niri-era finding that "the compositor is the
blocker" — see [`hdr-niri-june-2026.md`](hdr-niri-june-2026.md), which is now
historical (it applies only to the niri session).

## Verified state (2026-06-13)

| Component | Value |
|---|---|
| Compositor | Hyprland 0.55.0 (`f719bd6`) |
| OLED monitor | ASUS PG34WCDM, connector **DP-3**, `desc:ASUSTek COMPUTER INC PG34WCDM RCLMRS022510`, 3440x1440 **@143.97** (NOT @240 — see note) |
| Second monitor | ASUS ROG PG348Q, **DP-1**, portrait, SDR (left untouched) |
| GPU / driver | NVIDIA RTX 5080 / 595.45.04 |
| Color mgmt | `render:cm_enabled = true` — Hyprland advertises `wp_color_management_v1` to clients (no experimental flag needed in 0.55) |

> **Refresh rate is capped at 143.97Hz, not the panel's native 240Hz (2026-06-16).**
> 3440x1440@240 needs DSC to fit the DP 1.4 link, and DSC does not negotiate under
> the NVIDIA driver here — @240 trains no link and the OLED shows "no DisplayPort
> signal" while Hyprland reports the output on. @143.97 10-bit fits HBR3 without DSC
> and keeps full HDR. The `@239.984` in the example `hl.monitor`/`hl.eval` snippets
> below is **stale** — substitute `3440x1440@143.97` (and the live position is now
> `1440x1000`, not `900x355`). See the "OLED blanks at login" entry in
> `docs/hyprland.md` for the full diagnosis.

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

- **`cm = "srgb"` is the current default (changed 2026-07-21; was `"auto"`).**
  `"auto"` keeps the SDR desktop in proper SDR (preset reports `wide`) and only
  flips the *whole output* to the HDR/PQ curve (preset `hdr`) when a client
  presents HDR content — but that flip **drops the OLED's DP link** (monitor
  turns off) when triggered by fullscreen video in Helium. See "Learned
  behaviours" below. `"srgb"` with `bitdepth = 10` keeps the 10-bit desktop and
  can never mode-switch; re-test `"auto"` on a newer driver if HDR gaming lands.
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

2. **gamescope (the route pursued for WoW).** Steam launch options:
   ```
   DXVK_HDR=1 ENABLE_GAMESCOPE_WSI=1 gamescope -W 3440 -H 1440 -r 240 --hdr-enabled --adaptive-sync -f -- %command%
   ```
   This needs three things that were each initially broken on nebula — see below.

   **(a) A second Steam entry sharing the same prefix (so no WoW re-download).**
   Added a non-Steam shortcut to `…/Battle.net/Battle.net Launcher.exe` named
   "WoW (HDR)" with the gamescope launch options. A new shortcut gets its own
   `compatdata/<id>` prefix; to reuse the existing 122 GB install, launch the new
   shortcut once (creates a fresh ~400 MB prefix), then replace that fresh dir
   with a symlink to the real one:
   ```sh
   cd ~/.local/share/Steam/steamapps/compatdata
   mv <newid> <newid>.fresh-bak && ln -s 3082075026 <newid>   # 3082075026 = WoW/Bnet prefix
   ```
   (Find `<newid>` = newest dir by mtime after the one-shot launch. Never run both
   Battle.net entries at once — shared prefix, wineserver collision.)

   **(b) WoW must run DirectX 11, and it keeps reverting to DX12.** `DXVK_HDR=1`
   only affects DXVK (DX11); DX12 routes through vkd3d-proton and the flag is a
   no-op. WoW's in-menu API change needs a *client restart* to apply, so a
   mid-session switch is overwritten with the running value (D3D12) on exit —
   looks like it "reverts." Fix: edit `Config.wtf` while WoW is **closed**, set
   `SET gxApi "D3D11"`; WoW then starts in DX11 and writes D3D11 back on clean
   exit (sticks without locking the file). Path:
   `…/World of Warcraft/_retail_/WTF/Config.wtf`. **Bonus: switching DX12→DX11 also
   fixed the in-game judder** — the stutter was the vkd3d path, NOT the
   scanout/VRR theory (gamescope nested still can't direct-scanout on NVIDIA —
   `directScanoutBlockedBy: ["SW"]` persists even with `cm=srgb` — but DX11 plays
   smooth anyway).

   **(c) The gamescope FROG WSI layer must exist — nixpkgs disables it by default.**
   The layer (`libVkLayer_FROG_gamescope_wsi`) is what lets a Vulkan/DXVK client
   signal HDR to gamescope. nixpkgs `gamescope` builds with `enableWsi ? false`,
   and the layer ships as a *separate* package `pkgs.gamescope-wsi`. The NixOS
   module wires it via `hardware.graphics.extraPackages` when
   `programs.gamescope.enableWsi = true`. Without it, `--hdr-enabled` has no HDR
   client → gamescope outputs SDR mapped into the HDR container → washed-out
   **color shifts** (observed) and DP-3 stuck at `preset=wide`. **Fix applied in
   `configuration.nix`:** `programs.gamescope.enableWsi = true;` (drops
   `VkLayer_FROG_gamescope_wsi.x86_64.json` into `/run/opengl-driver/share/vulkan/
   implicit_layer.d/`, which Steam's pressure-vessel imports). Verify after switch:
   `ls /run/opengl-driver/share/vulkan/implicit_layer.d/ | grep -i frog`.

   **(d) NVIDIA driver ≥ 595.58.03 for native HDR-WSI.** snowglobe defaults to
   `nvidiaPackages.beta` (595.45.04 — *older* than production, pre-HDR-WSI).
   Overrode in `configuration.nix` to `nvidiaPackages.production` (595.80). Keep
   `hardware.nvidia.open = true` — REQUIRED on Blackwell (RTX 5080), no proprietary
   module exists. Avoided `latest` (610.43.02): new-feature branch with confirmed
   5080 Wayland memory leak + Blackwell DP HDR atomic-test failures. Driver swap
   needs a **reboot** (`nixos-rebuild boot` + reboot), then restart Steam.

   **OUTCOME 2026-06-13 (after reboot onto 595.80 + WSI layer): infra all works,
   but the result is washed out — nested gamescope HDR is a dead end on this box.**
   Verified working: driver 595.80, FROG layer in `/run/opengl-driver/.../implicit_layer.d/`
   (both arches), `libVkLayer_FROG_gamescope_wsi_x86_64.so` loaded into `WoW.exe`,
   gamescope log `server hdr output enabled: true` + `hdr formats exposed to client: true`,
   and `xdg_backend: cv_hdr_enabled: true` (gamescope detected Hyprland's HDR and
   tried to output HDR to it). **BUT** two unfixable problems:

   1. **WoW has no native HDR** (see Learned behaviours below) — so this only ever
      uses gamescope `--hdr-itm-enabled` synthetic inverse-tone-mapping. WoW's own
      swapchain stays SDR (`R8G8B8A8_UNORM` / `SRGB_NONLINEAR`).
   2. **Nested double color-management on NVIDIA washes it out.** With `cm=auto`,
      Hyprland kept DP-3 at `preset=wide` even though gamescope was emitting PQ →
      PQ shown through SDR = washed. Forcing DP-3 `cm=hdr` (via `hyprctl eval`) got
      `preset=hdr` and deepened blacks, but whites stayed muted / colors off:
      gamescope-ITM→PQ *then* Hyprland-CM→panel is two CM stages in series, and
      NVIDIA's Wayland color management is incomplete. ITM/gamut tuning
      (`--hdr-itm-sdr-nits`, `--sdr-gamut-wideness`) improved but did not fix it.
      OLED full-field luminance also caps perceived white brightness.

   **DECISION: WoW runs smooth native SDR** (the non-gamescope entry; DX11 fix means
   it's smooth — see (b)). DP-3 reverted to `cm=auto`. **Kept** `enableWsi = true` +
   595.80 — they're correct and benefit *genuinely* HDR titles and the gamescope
   session below. The "WoW (HDR)" Steam shortcut + its prefix symlink are left in
   place but unused (delete if desired; the fresh-prefix backup is
   `compatdata/<id>.fresh-bak`).

   **The one untested path that SHOULD give correct HDR: a gamescope-owns-DRM
   session** (gamescope on the bare display, no Hyprland in the color path — kills
   the double-CM). Already half-enabled: `programs.steam.gamescopeSession.enable =
   true` → a "Steam (gamescope)" entry at the login screen. Not tried this session;
   it's the right place to test real-HDR games or revisit WoW synthetic HDR.

To confirm a game actually went HDR: while it's running fullscreen,
`hyprctl monitors` for DP-3 should show `colorManagementPreset=hdr`. HDR video
also works via `mpv --target-colorspace-hint=yes`.

## Learned behaviours & workarounds

- **`cm = "auto"` + fullscreen Helium video turns the OLED off** (2026-07-21,
  driver 595.80). Fullscreening any YouTube video — even plain SDR bt709 —
  makes Chromium's `wp_color_management_v1` usage trigger `auto`'s PQ mode
  flip, and the modeset drops the DP link (same class as the 240Hz blank in
  `hyprland.md`; output reports enabled+dpms-on while the panel shows no
  signal). Ruled out: `misc.vrr` (blanked with vrr=0) and Helium's
  `force-color-profile=srgb` flag (blanked anyway — the flag doesn't stop the
  protocol-level poke). Fix: `cm = "srgb"` (10-bit kept); recover a blanked
  output live with the `hl.monitor{}` eval below.
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
- **WoW retail has NO native HDR — on any platform** (confirmed via Blizzard
  forums, Feb 2025: not implemented, not planned). The "HDR" Windows users see is
  OS-injected Auto HDR / NVIDIA RTX HDR, not the game. There is no in-game HDR
  toggle and no `Config.wtf` cvar (`gxHDR` etc. don't exist), and it's *not* gated
  on exclusive fullscreen (WoW removed that on all platforms in patch 8.0.1, 2018 —
  Windows also only has Windowed / Fullscreen-Windowed). `DXVK_HDR=1` only
  *advertises* HDR; WoW never requests an HDR swapchain, so it's a no-op. DX11 vs
  DX12 is irrelevant for HDR (ray-traced shadows are the DX12-only feature, not
  HDR). The only way to get HDR-on-panel for WoW on Linux is gamescope
  `--hdr-itm-enabled` synthetic ITM — and that washes out under nested Hyprland on
  NVIDIA (see gamescope route above). (2026-06-13)
- **gamescope `--hdr-enabled` HDR does NOT pass through cleanly when nested under
  Hyprland on NVIDIA.** gamescope's `xdg_backend` reports `cv_hdr_enabled: true`
  and emits PQ, but Hyprland `cm=auto` leaves the output at `preset=wide` →
  washed. Forcing `cm=hdr` engages HDR (deeper blacks) but the gamescope-ITM-PQ →
  Hyprland-CM double pass leaves whites muted / colors off. The reliable HDR path
  is gamescope owning DRM directly (dedicated session), not nesting. (2026-06-13)
- **WoW graphics-API (`gxApi`) reverts to D3D12** because an in-menu change needs a
  client restart; mid-session it's overwritten with the running value on exit. Set
  `SET gxApi "D3D11"` in `Config.wtf` while WoW is *closed* and it sticks. DX11
  (DXVK) also played noticeably smoother than DX12 (vkd3d) here. (2026-06-13)

## Sources

- [Hyprland — Color Management & HDR wiki](https://wiki.hypr.land/Configuring/HDR/)
- [Hyprland Monitors wiki](https://wiki.hypr.land/Configuring/Monitors/)
- Machine-verified on nebula via `hyprctl monitors` / `hyprctl eval`, 2026-06-13.
