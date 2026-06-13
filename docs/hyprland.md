# Hyprland manual (nebula)

A working reference for configuring Hyprland on `nebula`, distilled from the
official wiki at <https://wiki.hypr.land> and verified against the version
actually installed here. Maintained for Claude's use — keep it accurate, prune
anything that stops being true, and record real gotchas in **Learned behaviours
& workarounds** at the bottom.

## Version on nebula (read this first — it changes everything)

```
$ hyprctl version
Hyprland 0.55.2  (built from v0.55.2-b, 2026-05-16)
```

Installed via the official flake (`inputs.hyprland = github:hyprwm/Hyprland`,
see `flake.nix`), with the `hyprland-packages` / `hyprland-extras` overlays in
`overlays/default.nix`.

**0.55 is the cutover release.** As of 0.55 the configuration language is
**Lua** (`~/.config/hypr/hyprland.lua`, using an `hl.*` API). The old
`hyprlang` keyword syntax (`~/.config/hypr/hyprland.conf`, lines like
`bind = SUPER, Q, exec, kitty`) is **deprecated** but still parses. Almost
every config you find online — dotfile repos, the Arch wiki, old answers, and
three-quarters of the live wiki's own examples that haven't been migrated —
uses the **legacy `.conf` form**. This manual is **Lua-first** (that is what
0.55.2 runs and what `hyprland.lua` here is written in) and gives a
[legacy → Lua translation map](#legacy-conf--lua-translation) so you can port
any `.conf` snippet you find.

> When you read a `bind = …` / `windowrule = …` / `monitor = …` line anywhere,
> that is the **legacy** form. The Lua equivalent is `hl.bind(...)` /
> `hl.window_rule{...}` / `hl.monitor{...}`.

## Config files & load precedence (the #1 gotcha)

Hyprland reads from `~/.config/hypr/`. It looks for **`hyprland.conf` first**;
only if no `.conf` exists does it use **`hyprland.lua`**.

**Consequence observed on nebula:** if both files exist, the `.conf` wins and
the `.lua` is **silently ignored**. Confirm which one is live:

```sh
hyprctl binds | grep -c bind     # count active binds — match against each file
```

- Use **one** file. For 0.55+, that should be `hyprland.lua`. If a stub
  `hyprland.conf` is present (Hyprland writes one as a fallback — it literally
  says `# This config is a STUB! This should never be generated.`), delete or
  rename it so the `.lua` takes over.
- Auto-reload: saving the active config reloads it live. Force with
  `hyprctl reload`.
- Split config: `require("mycolors")` (Lua) or `source = ~/.config/hypr/x.conf`
  (legacy) to include other files.

## The Lua API (`hl.*`)

Everything is a function/table on the global `hl`. The shapes below are taken
from the upstream example config and the live wiki.

| Call | Purpose |
|---|---|
| `hl.config{ section = { … } }` | Set option sections (`general`, `decoration`, `input`, `dwindle`, `master`, `misc`, `animations`, `gestures`, `ecosystem`, …). Call it multiple times; each merges. |
| `hl.monitor{ output=, mode=, position=, scale= }` | Configure a monitor. |
| `hl.env("KEY", "VALUE")` | Set an environment variable (fires once at launch). |
| `hl.bind(keyspec, dispatcher, opts?)` | Keybind. Returns a handle (`:set_enabled(false)`). |
| `hl.dsp.*` | Dispatchers — the action passed to `hl.bind` (see table). |
| `hl.window_rule{ name=, match={…}, <rule>=… }` | Window rule. Returns a handle. |
| `hl.workspace_rule{ workspace=, <rule>=… }` | Workspace rule. |
| `hl.layer_rule{ name=, match={namespace=}, <rule>=… }` | Layer-surface rule. |
| `hl.gesture{ fingers=, direction=, action= }` | Touchpad gesture. |
| `hl.device{ name=, … }` | Per-input-device override. |
| `hl.curve(name, { type="bezier", points={{x,y},{x,y}} })` | Define a bezier (or `type="spring"` with `mass/stiffness/dampening`). |
| `hl.animation{ leaf=, enabled=, speed=, bezier=/spring=, style= }` | Configure one animation. |
| `hl.on("hyprland.start", function() hl.exec_cmd(...) end)` | Autostart hook. |
| `hl.exec_cmd(cmd)` | Run a shell command (use inside hooks). |
| `hl.permission(path, type, "allow")` | Grant an ecosystem permission. |

Lua is real Lua: use `local`, `for` loops, string concatenation (`mod .. " + Q"`),
`require`. That replaces the legacy `$var = …` user variables.

### Colors & gradients (Lua)

```lua
col = {
    active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
    inactive_border = "rgba(595959aa)",
}
```

Colors are `rgba(rrggbbaa)` / `rgb(rrggbb)` (hex, **no `#`**) or `0xAARRGGBB`.
A single string = solid; the `{ colors={…}, angle= }` table = gradient.

## Variables (`hl.config`)

Most-used options with defaults. Full list:
<https://wiki.hypr.land/Configuring/Basics/Variables/>.

### `general`
| Option | Default | Notes |
|---|---|---|
| `gaps_in` / `gaps_out` | `5` / `20` | inner / outer gaps |
| `border_size` | `1` | window border px |
| `col.active_border` / `col.inactive_border` | white / grey | gradient supported |
| `layout` | `"dwindle"` | `dwindle` \| `master` \| `scrolling` |
| `resize_on_border` | `false` | drag borders/gaps to resize |
| `allow_tearing` | `false` | needs per-window `immediate` rule + see Tearing page |

### `decoration`
| Option | Default |
|---|---|
| `rounding` / `rounding_power` | `0` / `2` |
| `active_opacity` / `inactive_opacity` | `1.0` / `1.0` |
| `blur = { enabled, size, passes, vibrancy }` | `true, 8, 1, …` |
| `shadow = { enabled, range, render_power, color }` | `true, 4, 3, …` |

### `input`
| Option | Default | Notes |
|---|---|---|
| `kb_layout` / `kb_variant` / `kb_options` | `us` / "" / "" | xkb |
| `follow_mouse` | `1` | 0 click-only … 3 full sloppy focus |
| `sensitivity` | `0` | −1.0 … 1.0 libinput accel |
| `repeat_rate` / `repeat_delay` | `25` / `600` | |
| `touchpad = { natural_scroll, disable_while_typing, tap-to-click }` | | |

### `misc`
`force_default_wallpaper` (`-1` random mascot, `0` off), `disable_hyprland_logo`,
`vfr` (`true`), `vrr` (`0` off / `1` on / `2` fullscreen-only),
`focus_on_activate`.

### `gestures`
In 0.55 gestures are declared with `hl.gesture{ fingers=3, direction="horizontal", action="workspace" }`
rather than the old `gestures { workspace_swipe = true }` block.

## Monitors

```lua
hl.monitor({ output = "DP-1", mode = "3440x1440@240", position = "0x0", scale = 1 })
hl.monitor({ output = "",     mode = "preferred", position = "auto", scale = "auto" })  -- catch-all
hl.monitor({ output = "HDMI-A-1", disabled = true })
```

- `mode`: `WxH@Hz`, or `preferred` / `highres` / `highrr` / `maxwidth`.
- `position`: `XxY` pixels (uses the **scaled+transformed** resolution), or
  `auto` / `auto-right` / `auto-left` / `auto-center-right` …
- `scale`: float or `"auto"`. Must divide the resolution cleanly (÷1.5 ok, ÷1.4 invalid).
- Extra fields: `transform = 0..7` (1=90°, 2=180°, 3=270°, 4–7 flipped),
  `mirror = "DP-2"`, `bitdepth = 10`, `vrr = 1`.
- Match by description instead of port: `output = "desc:Chimei Innolux …"`.
- Find names/modes: **`hyprctl monitors all`** (includes inactive). 10-bit
  caveat: border colors aren't 10-bit, and some apps can't screen-capture in 10-bit.

Bind a workspace to a monitor via a workspace rule (below), not the monitor line.

## Binds

```lua
hl.bind(keyspec, dispatcher, opts?)
```

- **keyspec** — a string: `"SUPER + Q"`, `"SUPER + SHIFT + 1"`, `"XF86AudioPlay"`,
  `"SUPER + mouse:272"`, `"SUPER + mouse_down"`. Mods: `SUPER`/`WIN`/`LOGO`/`MOD4`,
  `ALT`/`MOD1`, `CTRL`/`CONTROL`, `SHIFT`, `CAPS`. Keycodes: `"code:122"`.
  Mouse buttons: `mouse:272` (L), `273` (R), `274` (M); scroll: `mouse_up`/`mouse_down`.
- **opts** — `{ locked = true }` works on the lockscreen (media keys),
  `{ repeating = true }` repeats while held (volume/resize), `{ mouse = true }`
  for drag binds, plus `release`, `non_consuming`, `transparent`, `ignore_mods`,
  `long_press`, `description`. (These are the word forms of the legacy single-letter
  flags `l e r n m t i o d`.)
- Returns a handle: `local b = hl.bind(...); b:set_enabled(false)`.

```lua
local mod = "SUPER"
hl.bind(mod .. " + Q", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + C", hl.dsp.window.close())
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))

for i = 1, 10 do
    local key = i % 10                                   -- 10 → key 0
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),
        { locked = true, repeating = true })
```

### Dispatchers

Confirmed `hl.dsp.*` Lua forms (from the working example config) with their
legacy dispatcher names:

| `hl.dsp.*` (Lua) | Legacy dispatcher | Action |
|---|---|---|
| `hl.dsp.exec_cmd(cmd)` | `exec` | run a command |
| `hl.dsp.window.close()` | `killactive` | close focused window |
| `hl.dsp.window.float({ action = "toggle" })` | `togglefloating` | toggle float |
| `hl.dsp.window.pseudo()` | `pseudo` | toggle pseudotile |
| `hl.dsp.window.move({ workspace = n })` | `movetoworkspace` | move window to ws |
| `hl.dsp.window.drag()` *(`{mouse=true}`)* | `movewindow` | mouse-move |
| `hl.dsp.window.resize()` *(`{mouse=true}`)* | `resizewindow` | mouse-resize |
| `hl.dsp.focus({ direction = "left" })` | `movefocus` | move focus l/r/u/d |
| `hl.dsp.focus({ workspace = n })` | `workspace` | switch workspace |
| `hl.dsp.workspace.toggle_special("magic")` | `togglespecialworkspace` | scratchpad |
| `hl.dsp.layout("togglesplit")` | `layoutmsg togglesplit` | layout message |
| `hl.dsp.exit()` | `exit` | quit Hyprland |

The `hl.dsp` namespace mirrors the dispatcher set but isn't exhaustively
documented here. For any dispatcher without a known Lua wrapper, the **legacy
catalog below is authoritative** and is always reachable at runtime via
`hyprctl dispatch <name> <args>` (hyprctl uses the legacy names regardless of
config language). Verify exact Lua spelling against
<https://wiki.hypr.land/Configuring/Basics/Dispatchers/>.

**Full legacy dispatcher catalog** (name → args):

- **Exec/keys:** `exec`, `execr`, `pass window`, `sendshortcut MOD,key[,win]`,
  `global name`.
- **Window lifecycle:** `killactive`, `forcekillactive`, `closewindow win`,
  `killwindow win`, `exit`, `forcerendererreload`, `signal sig`.
- **Workspaces:** `workspace ws`, `movetoworkspace ws[,win]`,
  `movetoworkspacesilent ws[,win]`, `renameworkspace id name`,
  `togglespecialworkspace [name]`, `focusworkspaceoncurrentmonitor ws`,
  `movecurrentworkspacetomonitor mon`, `moveworkspacetomonitor ws mon`,
  `swapactiveworkspaces mon mon`.
- **State:** `togglefloating [win]`, `setfloating`, `settiled`,
  `fullscreen 0|1` (0=real, 1=maximize), `fullscreenstate internal client`,
  `pin`, `centerwindow`, `dpms on|off|toggle`.
- **Focus/move:** `movefocus l|r|u|d`, `movewindow dir|mon:NAME`,
  `swapwindow dir|win`, `cyclenext [prev|tiled|floating|visible]`,
  `swapnext [prev]`, `focuswindow win`, `focusmonitor mon`,
  `focuscurrentorlast`, `focusurgentorlast`, `tagwindow tag [win]`,
  `alterzorder top|bottom[,win]`.
- **Geometry:** `resizeactive X Y` (or `exact W H`), `moveactive X Y`,
  `resizewindowpixel X Y,win`, `movewindowpixel X Y,win`,
  `splitratio ±f|exact f`, `movecursortocorner 0..3`, `movecursor x y`.
- **Groups (tabbed):** `togglegroup`, `changegroupactive b|f|index`,
  `moveintogroup dir`, `moveoutofgroup`, `movewindoworgroup dir`,
  `movegroupwindow b`, `lockgroups lock|unlock|toggle`, `lockactivegroup`,
  `denywindowfromgroup on|off|toggle`.
- **Layout/mode:** `layoutmsg <msg>`, `submap name|reset`, `setprop win prop val`,
  `toggleswallow`.

Window selectors (for `win` args and rule matching): `class:RE`, `title:RE`,
`initialclass:RE`, `initialtitle:RE`, `tag:NAME`, `pid:PID`, `address:0x…`,
or a bare regex. Workspace selectors: absolute `N`, relative `+n`/`-n`,
existing-only `e+n`/`e-n`, `name:str`, `previous`, `empty`, `special[:name]`.

### Submaps (modal binds)

A submap is a named keybind mode. Legacy form (still valid; the cleanest way to
express it):

```
bind = SUPER, R, submap, resize
submap = resize
binde = , right, resizeactive, 10 0
binde = , left,  resizeactive, -10 0
bind  = , escape, submap, reset      # always include an exit
submap = reset
```

Recover from a stuck submap with `hyprctl dispatch submap reset`.

## Rules

### Window rules (`hl.window_rule`)

```lua
hl.window_rule({
    name  = "float-pavucontrol",          -- named rules can be toggled at runtime
    match = { class = "pavucontrol" },     -- RE2 regex; must FULLY match (since 0.46)
    float = true,
    size  = "800 600",
    center = true,
})
```

- **`match`** fields: `class`, `title`, `initialClass`, `initialTitle`, `tag`,
  `xwayland` (bool), `float` (bool), `fullscreen` (bool), `pinned` (bool),
  `focus` (bool), `workspace`, `onworkspace` (selector-capable), `content`
  (`none`/`photo`/`video`/`game`). Negate with a `negative:` prefix on a value.
  **Regexes must match the whole string** — use `.*tty.*`, not `tty`. Inspect
  windows with `hyprctl clients`.
- **Static rules** (applied once at open, match `initial*`): `float`, `tile`,
  `fullscreen`, `maximize`, `size W H`, `move X Y`, `center`, `pseudo`,
  `monitor id`, `workspace w [silent]`, `pin`, `noinitialfocus`,
  `suppress_event`, `noclosefor ms`, `persistentsize`, `nomaxsize`.
- **Dynamic rules** (re-evaluated on change): `opacity`, `bordercolor`,
  `idleinhibit none|always|focus|fullscreen`, `bordersize`, `rounding`,
  `noblur`, `noborder`, `noshadow`, `noanim`, `nofocus`, `minsize`, `maxsize`,
  `immediate` (tearing), `tag`, `dimaround`, `keepaspectratio`,
  `nearestneighbor`, `noscreenshare`. (Lua uses snake_case: `no_blur`,
  `border_color`, `min_size`, `suppress_event`, `no_focus`, …)
- **Evaluation:** top-to-bottom, **last match wins**. Opacity is *multiplicative*
  by default — append `override` for absolute values.
- Toggle a **named** rule live: `hyprctl keyword 'windowrule[name]:enable false'`.

```lua
hl.window_rule({ name="pip", match={ title="Picture-in-Picture" }, float=true, pin=true })
hl.window_rule({ name="suppress-maximize", match={ class=".*" }, suppress_event="maximize" })
```

### Workspace rules (`hl.workspace_rule`)

```lua
hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true })
hl.workspace_rule({ workspace = "name:gaming", monitor = "desc:ASUS …", persistent = true })
hl.workspace_rule({ workspace = "5", on_created_empty = "firefox" })
```

Rules: `monitor`, `default` (bool), `persistent` (bool), `gaps_in`/`gaps_out`,
`border_size`, `border`/`shadow`/`rounding`/`decorate` (bools),
`on_created_empty` (cmd), `default_name`, `layout`. Workspace **selectors** for
matching ranges: `r[A-B]`, `s[bool]` (special), `n[bool]` (named),
`m[monitor]`, `w[(flags)A-B]` (window count; flags `t`/`f`/`g`/`v`/`p`),
`f[-1|0|1|2]` (fullscreen state).

**Smart gaps** (no gaps with one tiled window) — both files needed:

```lua
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
hl.window_rule({ name="ng", match={ float=false, workspace="w[tv1]" }, border_size=0, rounding=0 })
```

### Layer rules (`hl.layer_rule`)

Match by `namespace` (see `hyprctl layers`). Rules: `blur`, `blurpopups`,
`ignorezero`/`ignorealpha a`, `noanim`, `dimaround`, `order n`,
`abovelock [interactable]`, `noscreenshare`.

```lua
hl.layer_rule({ name="blur-bar", match={ namespace = "waybar" }, blur = true, ignorezero = true })
```

## Layouts

Set with `general.layout`. Per-window/per-layout messages go through the
`layoutmsg` dispatcher (`hl.dsp.layout("…")`).

### Dwindle (`dwindle` section) — BSP binary tree
Splits are recomputed from each node's W/H ratio unless `preserve_split = true`
(you want this — it's set in the nebula config). Key options:
`pseudotile`, `force_split` (0 mouse / 1 left-top / 2 right-bottom),
`preserve_split`, `smart_split`, `smart_resizing`, `default_split_ratio`,
`split_width_multiplier` (useful on ultrawide), `special_scale_factor`.
`layoutmsg`: `togglesplit`, `swapsplit`, `preselect l|r|u|d`, `movetoroot`.

### Master (`master` section)
One/more masters + a stack. Options: `mfact` (0.55), `new_status`
(`master`/`slave`/`inherit`), `new_on_top`, `orientation`
(`left`/`right`/`top`/`bottom`/`center`), `slave_count_for_center_master`.
`layoutmsg`: `swapwithmaster`, `focusmaster`, `addmaster`, `removemaster`,
`orientationleft|right|top|bottom|center|next|prev`, `mfact ±f|exact f`,
`cyclenext`, `rollnext`.

### Scrolling (`scrolling` section)
Newer niri-like layout. nebula's config sets `fullscreen_on_one_column = true`.

## Animations

```lua
hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("easy",         { type = "spring", mass = 1, stiffness = 71.26, dampening = 15.83 })

hl.animation({ leaf = "windows",   enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1,  spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "workspaces",enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
```

- `speed` is in deciseconds (1 = 100 ms).
- **Leaf tree** (each inherits its parent): `global` → `windows`
  (`windowsIn`/`windowsOut`/`windowsMove`) → `layers` → `fade`
  (`fadeIn`/`fadeOut`/…) → `border` → `borderangle` → `workspaces`
  (`workspacesIn`/`workspacesOut`/`specialWorkspace`) → `zoomFactor`.
- Styles: `popin N%` (windows), `slide [left|right|top|bottom]`,
  `slidefade N%` / `slidevert` (workspaces). `borderangle` with `loop` runs
  continuously (CPU/battery cost).

## Environment variables & NVIDIA (RTX 5080)

**On nebula the NVIDIA plumbing is handled by snowglobe-lib**, not by hand:
`gpu-vendors = [ "nvidia" ]` in `nixosConfigurations/default.nix` pulls in the
driver, KMS, and `NIXOS_OZONE_WL=1` (verified set in-session). The RTX 5080 is
a 50-series card, so the **open kernel modules are mandatory** — snowglobe’s
NVIDIA module enables `hardware.nvidia.open` and modeset by default on recent
drivers. Don't hand-roll modprobe/modeset config; if something’s missing, fix it
in the snowglobe NVIDIA path, not in a one-off module.

Wayland/NVIDIA env vars (set in Hyprland with `hl.env(...)` only if snowglobe
doesn't already export them — check `env | grep -iE 'GBM|GLX|LIBVA|OZONE'` first):

```lua
hl.env("LIBVA_DRIVER_NAME", "nvidia")          -- VA-API
hl.env("GBM_BACKEND", "nvidia-drm")            -- force GBM backend
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
```

Notes:
- `AQ_DRM_DEVICES` is **only** for multi-GPU selection — a single 5080 does
  **not** need it.
- `NIXOS_OZONE_WL=1` (already set) makes Electron/Chromium run native Wayland —
  the standard fix for Electron flicker; don't also set `ELECTRON_OZONE_PLATFORM_HINT`.
- `cursor:no_hardware_cursors` is **no longer** the documented NVIDIA flicker
  fix in current Hyprland — set it only if you actually observe cursor flicker.
- XWayland-game flicker is solved by explicit sync (driver ≥ 555, which the 5080
  requires anyway).

General toolkit env (from the wiki, set as needed): `GDK_BACKEND=wayland,x11,*`,
`QT_QPA_PLATFORM=wayland;xcb`, `SDL_VIDEODRIVER=wayland`,
`QT_QPA_PLATFORMTHEME=qt6ct`, `XDG_CURRENT_DESKTOP=Hyprland`. Don't put Wayland
env vars in `/etc/environment` (leaks into Xorg sessions). `MOZ_ENABLE_WAYLAND`
is obsolete — Firefox defaults to Wayland.

## hyprctl (runtime control)

`hyprctl [-j] <command>` (`-j` = JSON; `--batch "a ; b"` to chain).

| Command | Use |
|---|---|
| `hyprctl monitors all` | list outputs + modes (incl. inactive) |
| `hyprctl clients` | all windows + class/title/state (for rules) |
| `hyprctl activewindow` | focused window info |
| `hyprctl workspaces` / `layers` / `devices` / `binds` | introspection |
| `hyprctl dispatch <name> <args>` | run any dispatcher (legacy names) |
| `hyprctl keyword <opt> <val>` | set an option live, e.g. `decoration:rounding 10` |
| `hyprctl getoption <opt>` | read an option (`set: false` ⇒ still default) |
| `hyprctl reload` | force config reload |
| `hyprctl setcursor <theme> <size>` | cursor theme/size |
| `hyprctl version` | build/version |

`getoption` is the fastest way to tell **which config actually loaded** — if the
value differs from your file and shows `set: false`, your file isn't being read.

## Ecosystem (separate hypr* tools)

- **hypridle** — idle daemon (`~/.config/hypr/hypridle.conf`; lock/dpms/sleep
  timeouts). Enable as a user service.
- **hyprlock** — GPU screen locker; needs a config or it refuses to lock.
- **hyprpaper** — IPC wallpaper utility.
- **xdg-desktop-portal-hyprland (xdph)** — screenshare + global shortcuts
  portal (the `hyprland-extras` overlay here provides it). Has **no file
  picker** — pair with `xdg-desktop-portal-gtk`.
- **hyprpm** — official plugin manager. **Unsupported on Nix.** Use the Hyprland
  Nix plugin mechanism instead (<https://wiki.hypr.land/Nix/Plugins/>).

## Legacy `.conf` → Lua translation

When porting a snippet you found online:

| Legacy `hyprland.conf` | Lua `hyprland.lua` |
|---|---|
| `$mod = SUPER` | `local mod = "SUPER"` |
| `monitor = DP-1,1920x1080@144,0x0,1` | `hl.monitor{ output="DP-1", mode="1920x1080@144", position="0x0", scale=1 }` |
| `env = KEY,VALUE` | `hl.env("KEY", "VALUE")` |
| `exec-once = waybar` | `hl.on("hyprland.start", function() hl.exec_cmd("waybar") end)` |
| `general { gaps_in = 5 }` | `hl.config{ general = { gaps_in = 5 } }` |
| `bind = SUPER, Q, exec, kitty` | `hl.bind("SUPER + Q", hl.dsp.exec_cmd("kitty"))` |
| `bindm = SUPER, mouse:272, movewindow` | `hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })` |
| `binde = ,XF86AudioRaiseVolume, exec, …` | `hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("…"), { repeating = true })` |
| `windowrule = float, class:^(pavucontrol)$` | `hl.window_rule{ match={ class="pavucontrol" }, float=true }` |
| `workspace = 1, monitor:DP-1, default:true` | `hl.workspace_rule{ workspace="1", monitor="DP-1", default=true }` |
| `layerrule = blur, waybar` | `hl.layer_rule{ match={ namespace="waybar" }, blur=true }` |
| `bezier = name,0.05,0.9,0.1,1.05` | `hl.curve("name", { type="bezier", points={{0.05,0.9},{0.1,1.05}} })` |
| `animation = windows,1,7,name` | `hl.animation{ leaf="windows", enabled=true, speed=7, bezier="name" }` |

Bind flag letters → opts: `l`→`locked`, `e`→`repeating`, `r`→`release`,
`m`→`mouse`, `n`→`non_consuming`, `t`→`transparent`, `i`→`ignore_mods`,
`o`→`long_press`, `d`→`description`. Rule names → snake_case: `noblur`→`no_blur`,
`bordercolor`→`border_color`, `idleinhibit`→`idle_inhibit`, etc.

## Learned behaviours & workarounds

Real findings on nebula — append as you discover more; correct/remove stale ones.

- **`.conf` shadows `.lua` (2026-06-13).** With both
  `~/.config/hypr/hyprland.conf` and `hyprland.lua` present, Hyprland 0.55.2
  loads the `.conf` and **silently ignores the `.lua`**. Observed: the 13 KB
  `hyprland.lua` (rounding 10, border 2, ~40 binds) was inert while a 6-bind
  stub `.conf` was live — `hyprctl binds | grep -c bind` returned 6, and
  `hyprctl getoption decoration:rounding` returned `0 / set:false`. **Fix:**
  delete/rename the stub `hyprland.conf` so the `.lua` is used. Always confirm
  the live config with `hyprctl getoption` / `hyprctl binds`, not by reading the
  file you *think* is active.
- **Hyprland writes a stub `.conf` as a fallback.** It self-identifies
  (`# This config is a STUB! This should never be generated.`). If you see it,
  Hyprland fell back to it because it didn't pick up your `.lua` — that stub is
  the thing shadowing your real config (see above).
- **0.55 = Lua, but the internet is `.conf`.** Treat every online example as
  legacy syntax and translate (table above). Don't paste `bind = …` lines into
  `hyprland.lua`.
- **Hyprland config is NOT yet in the stow tree (2026-06-13).** `home/` has no
  `hypr` package; `~/.config/hypr/{hyprland.lua,hyprland.conf}` are plain
  unmanaged files. To track them in this repo, adopt into stow once you've
  settled on the Lua file:
  `dots-adopt hypr .config/hypr/hyprland.lua` (see CLAUDE.md → Dotfiles). Don't
  adopt the throwaway stub `.conf`.
- **NVIDIA is snowglobe-owned.** Driver/KMS/open-modules/`NIXOS_OZONE_WL` come
  from `gpu-vendors = ["nvidia"]` in `nixosConfigurations/default.nix`. The 5080
  *requires* the open modules. Don't add hand-rolled NVIDIA env/modprobe in
  Hyprland or a stray nix module — fix it in the snowglobe NVIDIA path.
- **Two compositors are enabled.** `configuration.nix` has both
  `desktop.niri.enable` and `desktop.hyprland.enable = true`, with
  `displayManager.defaultSession = "hyprland-uwsm"`. Both sessions are
  selectable at login; Hyprland runs under **uwsm**. Displays elsewhere are
  driven by kanshi under niri — Hyprland does its own monitor config via
  `hl.monitor{}`, so monitor layout must be set in *both* places if you switch
  between sessions.

## Sources

- Hyprland wiki — <https://wiki.hypr.land> (Getting-Started, Configuring/Basics/*,
  Configuring/Layouts/*, Configuring/Advanced-and-Cool/*, Nvidia, Nix/Plugins)
- Legacy-syntax archive — <https://wiki.hypr.land/0.54.0/>
- Upstream example Lua config —
  <https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua>
  (mirrored at `~/.config/hypr/hyprland.lua`)
- Verified locally against `hyprctl version` (0.55.2), `hyprctl binds`,
  `hyprctl getoption`, and the on-disk configs, 2026-06-13.
