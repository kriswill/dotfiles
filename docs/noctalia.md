# Noctalia shell manual (nebula)

A working reference for the **Noctalia** Wayland desktop shell as installed and
run on `nebula` (under Hyprland). Distilled from the upstream repo, the docs at
<https://docs.noctalia.dev/v5>, and — where they disagree — **verified against
the binary and config actually on this machine**. Maintained for Claude's use:
keep it accurate, prune anything that stops being true, and record real gotchas
in **Learned behaviours & workarounds** at the bottom.

## Version & state on nebula (read this first — it changes everything)

```
$ noctalia --version
noctalia v5.0.0
$ readlink -f $(command -v noctalia)
/nix/store/…-noctalia-5.0.0/bin/noctalia
```

- **This is the v5 line, in-development / alpha.** There is **no published
  `v5.0.0` GitHub release tag** — the latest *release* is **v4.7.7 (2026-05-13)**,
  whose notes say it is the last v4 release. The `5.0.0` you run is built from
  **branch `main` HEAD** at the pinned flake rev (`meson.build` declares
  `version: '5.0.0'`). Upstream warns: *"Noctalia v5 is in early/alpha
  development. Expect breaking configuration and behavior changes."* Re-verify
  facts here after any `nix flake update`.
- **Pinned rev:** `noctalia-dev/noctalia-shell` @ `28a38bf…` (see `flake.lock`,
  `lastModified` 2026-06-16). Bump with `nix flake update` (or
  `nix flake lock --update-input noctalia`).
- **Verified against:** `noctalia --version`, `noctalia --help`,
  `noctalia msg --help`, `noctalia theme --help`, `noctalia config --help`,
  `noctalia msg status`, `noctalia config validate`, the live
  `~/.local/state/noctalia/settings.toml`, the pinned source tree
  (`flake.nix`, `nix/*.nix`, `example.toml`, `assets/templates/`), and
  `ldd`/`strings` on the installed ELF — all on **2026-06-19**.

## What it is

Noctalia is a **single self-contained `noctalia` binary** that provides the whole
"shell layer" around your Wayland compositor: multi-monitor **bars** with
widgets, a **dock**, an app **launcher**, a **control center**, **notifications**
(toasts + history + DND), **wallpaper** management, a **lock screen**, **session**
actions, **clipboard history**, **OSDs**, **system-tray** integration, and
**desktop/lockscreen widgets** — instead of stitching together waybar + a
launcher + a notifier + a locker + a wallpaper daemon + a settings UI.

> **v5 is a native C++ rewrite — NOT Quickshell/QML.** This is the single most
> important architectural fact and the easiest to get wrong (the v4 line *was*
> Quickshell-based, and a lot of third-party material still describes that).
> Machine-verified three ways on nebula:
> - `ldd` on the binary links `libwayland-client`, `libEGL`, `libGLESv2`,
>   `libwayland-egl`, `libcairo`, `libpango`, `libharfbuzz`, `libsdbus-c++`,
>   `libpipewire-0.3`, `libpolkit-*` — and **zero Qt / QML / Quickshell**.
> - `strings` on the binary contains **no** `quickshell`/`QtQuick`/`qmlRegister`
>   tokens, but **does** contain `material_color_utilities` symbols.
> - `meson.build` is `project('noctalia', ['c', 'cpp'], version: '5.0.0')` and
>   `nix/package.nix` is a plain `stdenv.mkDerivation` (meson/ninja, C++23).
>
> **Treat DeepWiki, the AUR `noctalia-shell` description, and older blog posts
> that say "Quickshell/QML/`qs -c noctalia-shell`" as historical v4 docs.** They
> do not describe the v5 you run.

- **License:** MIT.
- **Compositors supported:** niri, **Hyprland** (nebula), sway, scroll, mango,
  labwc, triad, dwl, and other layer-shell-capable Wayland compositors.
  Workspace integration uses compositor-native backends or `ext-workspace-v1`.
- **Repo / links:** canonical GitHub repo is **`noctalia-dev/noctalia`**; the
  org renamed `noctalia-shell` → `noctalia` and the old URL **HTTP-redirects**,
  which is why the flake input `github:noctalia-dev/noctalia-shell` still
  resolves. Codeberg mirror: `codeberg.org/noctalia-dev/noctalia-shell`.
  Site <https://noctalia.dev> · Docs <https://docs.noctalia.dev> (v5 tree under
  `/v5/`, v4 archived under `/v4/`) · Discord <https://discord.noctalia.dev>.
  The **display/login greeter is a separate project**:
  `github.com/noctalia-dev/noctalia-greeter` (synced via `noctalia msg
  greeter-sync`).
- **v5 vs v4 in one line:** v5 dropped the Qt/Quickshell stack for a native
  Wayland+GLES runtime; upstream claims memory dropped from ~300 MB/monitor (v4)
  to ~50 MB/monitor (v5). Old QML plugins do not carry over.

## How it's installed here (Nix)

Noctalia is a **flake input**, consumed as a **plain user package** — *not* via a
Home-Manager / NixOS module.

`flake.nix`:

```nix
noctalia = {
  url = "github:noctalia-dev/noctalia-shell";   # redirects to noctalia-dev/noctalia
  inputs.nixpkgs.follows = "nixpkgs";
};
```

`modules/hosts/nebula/users/k/noctalia.nix` adds the package to `k` and enables
the background services the shell surfaces:

```nix
users.users.k.packages = [
  inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
  # + brightnessctl cliphist wl-clipboard matugen cava  (see "Recommended cleanup")
];
services.upower.enable = true;
services.power-profiles-daemon.enable = true;
hardware.bluetooth.enable = true;          # networkmanager already on (k is in the group)
```

It is **launched and driven from the stow-managed Hyprland Lua config**
(`home/hyprland/.config/hypr/hyprland.lua`), not by a systemd unit — see
**nebula wiring** below.

### What the upstream flake actually exposes (at the pinned rev)

Read directly from the pinned source `flake.nix` + `nix/`:

| Output | Notes |
|---|---|
| `packages.<system>.default` | the only package (`x86_64-linux`, `aarch64-linux`). What nebula uses. |
| `overlays.default` | adds `pkgs.noctalia`. |
| `apps.<system>.default` | `nix run` entry. |
| `devShells.<system>.default` | meson/ninja/clang dev shell. |
| `homeModules.default` | **Home-Manager** module → `programs.noctalia.*` (see below). Note: `homeModules`, not `homeManagerModules`. |
| `hjemModules.default` | [hjem](https://github.com/feel-co/hjem) module, same `programs.noctalia.*` namespace. |

**There is NO `nixosModules.*` at this pin** (`nix/` contains only
`package.nix`, `home-module.nix`, `hjem-module.nix`, `devshell.nix`). Upstream
`main` may later add a `nix/nixos-module.nix`; if so it won't be in use here
until the input is bumped.

**The Home-Manager module** (`nix/home-module.nix`), for reference if we ever
adopt home-manager — `options.programs.noctalia`:

| Option | Type / default | Effect |
|---|---|---|
| `enable` | bool | turn it on |
| `package` | package | defaults to the flake's package |
| `systemd.enable` | bool | install a `noctalia` **user service** bound to the Wayland session target (`Restart=on-failure`) |
| `settings` | TOML attrset \| string \| path (`{}`) | written to **`~/.config/noctalia/config.toml`** (the *config-home* layer — see config layering) |
| `customPalettes` | JSON attrset \| string \| path (`{}`) | written to `~/.config/noctalia/palettes/<name>.json` |
| `validateConfig` | bool (`true`) | runs `noctalia config validate` on the generated config at **build time** |

nebula deliberately uses **none** of this — it installs the bare package and
lets the shell manage `settings.toml` itself (GUI + IPC). Documented so nobody
"discovers" that Noctalia has no module — it has one; we just don't use it.

## CLI surface

```
noctalia [-h|--help] [-v|--version] [-d|--daemon]

Subcommands:
  noctalia msg <command> [args]   # IPC to the running instance  (the workhorse)
  noctalia theme <image> [opts]   # generate / render color palettes & templates
  noctalia config <command>       # validate / export / replay support reports
```

- `noctalia --daemon` starts the shell in the background (how nebula autostarts it).
- **Single instance:** a second `noctalia` prints `error: noctalia is already
  running` and exits (exit 0). There is **no `restart` subcommand** (upstream FR
  was closed *not planned*). **Clean restart = `pkill -x noctalia; noctalia
  --daemon`** — that's our pattern, not a documented command.
- **Reload without restart:** `noctalia msg config-reload`. Treat it as
  best-effort; **restart for structural changes** (e.g. adding a second bar).

### `noctalia config`

- `config validate [path]` — TOML syntax + unknown/misspelled keys + bad values;
  exit 1 on error. No path = the active config-home + state `settings.toml`.
  (Live on nebula: `✓ Config is valid`.)
- `config export [merged|full]` — print the active config as TOML (default
  `merged`).
- `config replay-report <report.toml> --target <dir> [--flattened] [--force]` —
  reconstruct a config from a support report (`--flattened` = one merged
  `config.toml`).

## Configuration

### Where config lives — two merged TOML layers

| Layer | Path | Who writes it |
|---|---|---|
| **config-home** (hand-written / declarative) | `~/.config/noctalia/*.toml` — **every** `*.toml` here, merged **alphabetically** | you (or the HM module → `config.toml`) |
| **state-home** (runtime overrides) | `~/.local/state/noctalia/settings.toml` | the **Settings GUI** and `noctalia msg` commands |

**state-home loads LAST and wins on conflicts.** Both layers hot-reload (inotify).

`config.toml` is **not** special — it's just one conventional filename inside
config-home that participates in the alphabetical merge.

> **On nebula:** `~/.config/noctalia/` is **empty** — we never hand-write config.
> Everything lives in `~/.local/state/noctalia/settings.toml`, managed via the
> GUI / IPC. The state dir also holds: `clipboard/`, `community-palettes/`,
> `community-templates/` (+`catalog.json`), `plugins/sources/{official,community}/`,
> `notification_history.json`, `recently_used.json`, `screen_time.json`,
> `usage_counts.json`, `.setup-complete`.

**The canonical, fully-commented config with all defaults ships as
`example.toml` in the repo** (≈440 lines) — the best reference for exact keys and
defaults. The docs site sometimes lags it.

### Settings GUI

`noctalia msg settings-open` (also `settings-close` / `settings-toggle`). The
GUI writes to **state-home `settings.toml`**. `[shell].settings_show_advanced =
true` exposes advanced settings (set on nebula).

### Major sections (from `example.toml` + live config)

- **`[shell]`** — `ui_scale`, `corner_radius_scale` (0 square…2 extra-round),
  `font_family`, `time_format`/`date_format`, `polkit_agent`,
  `settings_show_advanced`, `clipboard_enabled` + `clipboard_history_max_entries`
  (10–10000) + `clipboard_auto_paste`, `offline_mode`, `telemetry_enabled`,
  `app_icon_colorize`. Sub-tables: `[shell.animation]` (`enabled`, `speed`),
  `[shell.shadow]`, `[shell.panel]` (`transparency_mode` solid|soft|glass, the
  `*_placement` attached|floating|centered per panel, `open_near_click_*`),
  `[shell.screen_corners]`, `[shell.screenshot]` (`directory`, …),
  `[shell.mpris]` (`blacklist`). `screen_time_enabled` is also present at runtime.
- **`[bar.<name>]`** — one table per bar (nebula has a single bar literally named
  `bar`, so `[bar.bar]`; `[bar].order` lists active bars). Keys: `position`
  (top|bottom|left|right), `thickness`, `background_opacity`, `radius`,
  `margin_h`/`margin_v` (example.toml) ≈ `margin_edge`/`margin_ends` (live),
  `padding`, `widget_spacing`, `scale`, `shadow`, `auto_hide`, `reserve_space`,
  `capsule`/`capsule_*`. **Widget lanes:** `start`, `center`, `end` (lists of
  widget ids). **Capsule groups:** `[[bar.<name>.capsule_group]]` with
  `id`/`members`/`fill`/`opacity`/`padding`, referenced in a lane as
  `"group:<id>"`. **Per-monitor override:** `[bar.<name>.monitor.<key>]` with a
  `match = "DP-1"` and only the overridden fields.
- **`[dock]`** — `enabled` (off by default), `position`, `icon_size`,
  paddings/spacing, `background_opacity`, `radius[_*]`, `magnification`(`_scale`),
  `active/inactive_scale`/`_opacity`, `show_running`, `show_dots`,
  `auto_hide`, `reserve_space`, `active_monitor_only`, `launcher_position`
  (none|start|end), `launcher_icon` (a Tabler glyph name), `pinned = ["firefox",
  …]`.
- **`[theme]`** + **`[theme.templates]`** — see **Theming** below.
- **`[notification]`** — `enable_daemon`, `show_app_name`, `show_actions`,
  `layer` (top|overlay), `scale`, `background_opacity`, `offset_x`/`offset_y`,
  `position` (live). Per-app filters: `[notification.filter.<name>]`
  (`match`, `show_toast`, `save_history`, `play_sound`, `allowed_urgencies`).
- **`[osd]`** + `[osd.kinds]` — OSD `position`/`orientation`/`scale`, and toggles
  per kind (volume, brightness, wifi, bluetooth, power_profile, caffeine, dnd,
  lock_keys, keyboard_layout).
- **`[wallpaper]`** — `enabled`, `fill_mode`, `transition`(`_duration`),
  `directory`(`_light`/`_dark`), `[wallpaper.default]`, `[wallpaper.automation]`
  (slideshow: `interval_minutes`, `order` random|alphabetical, `recursive`).
  Live also tracks `[wallpaper.last]` and `[wallpaper.monitors.<conn>]`.
  **Noctalia paints the desktop wallpaper** — there is no separate wallpaper
  daemon on nebula (hyprpaper was removed).
- **`[location]`** / **`[weather]`** — location resolution priority
  `auto_locate` (IP) → `address` → `latitude`/`longitude` → fixed
  `sunset`/`sunrise`; feeds Weather, Night Light, and Theme `auto` mode. Weather
  `enabled`, `unit` (celsius|fahrenheit / imperial live), `refresh_minutes`.
- **`[lockscreen]`** — `enabled`, `blurred_desktop`, `blur_intensity`,
  `tint_intensity`, optional `wallpaper`, `monitors`. (`allow_empty_password`
  set live.)
- **`[system.monitor]`** — sampling toggles + poll intervals (`cpu_poll_seconds`,
  `gpu_poll_seconds`, `memory_poll_seconds`, `network_poll_seconds`,
  `disk_poll_seconds`).
- **`[audio]`** — `enable_overdrive` (>100%), `enable_sounds`, `sound_volume`,
  custom sound paths.
- **`[brightness]`** — `enable_ddcutil` (external monitors via DDC/CI),
  `ignore_mmids`, `minimum_brightness`, per-monitor
  `[brightness.monitor.<conn>].backend` (auto|none|backlight|ddcutil).
- **`[nightlight]`** — `enabled`, `force`, `temperature_day`/`_night` (Kelvin).
- **`[backdrop]`** — dim/blur behind open panels.
- **`[desktop_widgets]`** / **`[lockscreen_widgets]`** — see **Widgets** below.
- **`[widget.<name>]`** — per-widget tuning (e.g. `[widget.clock]` `format`,
  `scale`, `font_weight`; `[widget.keyboard_layout]`, `[widget.custom_button]`).
- **`[idle]` / `[idle.behavior.<name>]`** — idle actions: `timeout`, `command`,
  optional `resume_command`, `enabled`. Built-ins `lock` and `screen-off`.
  Commands may be shell commands or `noctalia:<ipc>` (e.g. `noctalia:dpms-off`).
  `[idle].pre_action_fade_seconds` fades an overlay first; input cancels.
- **`[keybinds]`** — *in-panel* navigation keys (validate/cancel/arrows), **not**
  global compositor binds (those live in the compositor).
- **`[hooks]`** — map events to commands. Events include `started`,
  `wallpaper_changed`, `colors_changed`, `theme_mode_changed`,
  `session_locked`/`unlocked`, `logging_out`, `rebooting`, `shutting_down`,
  `wifi_*`, `bluetooth_*`, `battery_state_changed`, `battery_under_threshold`
  (gated by `battery_low_percent_threshold`), `power_profile_changed`. Several
  export `NOCTALIA_*` env vars (e.g. `$NOCTALIA_THEME_MODE`,
  `$NOCTALIA_BATTERY_PERCENT`).
- **`[[control_center.shortcuts]]`** — up to 6 dashboard shortcut buttons
  (`type = wifi|bluetooth|nightlight|notification|wallpaper|screen_recorder|session`).

## Theming, color schemes & templates

### Color source

`[theme]` selects the palette. `source` is one of **`builtin | wallpaper |
community | custom`** (all four selector keys persist; only the active source is
used):

- **`builtin`** + `builtin = "<name>"` — bundled palettes: **Ayu, Catppuccin,
  Dracula, Eldritch, Gruvbox, Kanagawa, Noctalia, Nord, Rosé Pine, Tokyo-Night**.
- **`wallpaper`** + `wallpaper_scheme = "<scheme>"` — generate a Material-You
  palette from the current wallpaper. Schemes: `m3-tonal-spot` (default),
  `m3-content`, `m3-fruit-salad`, `m3-rainbow`, `m3-monochrome` (Material
  Design 3), and custom HSL `vibrant`, `faithful`, `dysfunctional`, `muted`.
- **`community`** + `community_palette = "<name>"` — fetched from
  `api.noctalia.dev`, cached under `community-palettes/`.
- **`custom`** — user palette JSON under `~/.config/noctalia/palettes/<name>.json`.

`mode = dark | light | auto` (auto follows the location's day/night).

> **Generation is built in** — Noctalia vendors **Material Color Utilities**
> (confirmed in the binary's symbols). **`matugen` is NOT used by v5** (absent
> from the binary and closure). Community templates that ship `matugen-template.*`
> files just reuse the matugen *token syntax*; they don't require the matugen
> binary.

**On nebula:** `source = "wallpaper"`, `wallpaper_scheme = "m3-rainbow"`
(`color-scheme-get` → `wallpaper m3-rainbow`), with `builtin = "Rosé Pine"` and
`community_palette = "Oxocarbon"` dormant. Wallpaper:
`~/Pictures/Wallpapers/nebula-1.jpg` on both DP-1 and DP-3.

### Templates (recolor external apps to match the palette)

Noctalia re-renders config for external apps whenever the palette changes.

- **Enable built-ins:** `[theme.templates].builtin_ids = ["hyprland", …]`
  (list ids with `noctalia theme --list-templates`). The **20 built-in
  template ids** (this build): `alacritty`, `btop`, `cava`, `emacs`, `foot`,
  `ghostty`, `gtk3`, `gtk4`, `helix`, `hyprland`, `kcolorscheme`, `kitty`,
  `labwc`, `mango`, `niri`, `qt`, `scroll`, `starship`, `sway`, `wezterm`.
  (`gtk3`/`gtk4` are separate ids both sourced from the bundled `gtk/` dir;
  older asset trees had a single `gtk`/`kde` — the installed build splits them.)
- **Community templates:** `[theme.templates].enable_community_templates` +
  `community_ids` (from `api.noctalia.dev/templates`, cached under
  `community-templates/`).
- **User templates:** declared inline —
  `[theme.templates.user.<name>]` with `input_path`, `output_path`,
  `post_hook`.
- **Force a re-render:** `noctalia msg templates-apply`.
- **Token syntax:** `{{ colors.<role>.<mode>.<format> }}`, e.g.
  `{{colors.primary.default.hex_stripped}}`. Roles are the Material-You set
  (`primary`, `secondary`, `tertiary` + `on_*`/`*_container`/`*_fixed*`,
  `surface`, `surface_variant`, `surface_container_*`, `outline`,
  `outline_variant`, `inverse_surface`, `error`(`_container`), `shadow`,
  plus `terminal_*` ANSI roles). Formats include `hex`, `hex_stripped`, `rgb`,
  `rgb_csv` (+ filters like `lighten`/`darken`); the full list is in the docs.
- **Render manually:** `noctalia theme <image> --scheme <m3-…> [--dark|--light|
  --both] [-o out.json]`, render a single template with `-r in:out`, a template
  config with `-c file.toml`, or the shipped catalog with `--builtin-config`.

### How the Hyprland template works (what's wired on nebula)

The `hyprland` built-in template is **dynamic**: its `apply.sh {input|output|
apply}` detects whether Hyprland is in **Lua** mode (≥0.55) or legacy `.conf`
mode, then:

1. renders `~/.config/hypr/noctalia.lua` from the template (`{{colors.*}}` →
   concrete `rgb(...)`), and
2. injects `-- For Noctalia Color templates` + `require("noctalia")` into
   `hyprland.lua` (or `source = ~/.config/hypr/noctalia.conf` for legacy).

So the generated `~/.config/hypr/noctalia.lua` calls `hl.config({...})` to set
border colors (`general.col.active_border = primary`, group colors, etc.) from
the live palette. The `require("noctalia")` line at the bottom of our
`home/hyprland/.config/hypr/hyprland.lua` is what loads it. **`noctalia.lua` is
generated — don't hand-edit it.** (Note: it's written to the real `~/.config/hypr`
dir, *not* the stow tree, so it isn't tracked in the repo.)

## Widgets, panels, launcher, dock

### Bar widget ids

From the binary's widget classes + the docs catalog. Add these to a bar lane
(`start`/`center`/`end`):

`active_window`, `audio_visualizer`, `battery`, `bluetooth`, `brightness`,
`clipboard`, `clock`, `control-center`, `custom_button`, `keyboard_layout`,
`launcher`, `lock_keys`, `media`, `network`, `nightlight`, `notifications`,
`power_profile`, `privacy`, `screenshot`, `session`, `spacer`, `sysmon`,
`taskbar`, `theme_mode`, `tray`, `volume`, `wallpaper`, `weather`, `workspaces`,
plus **`caffeine`** (the idle-inhibitor widget).

Notes:
- The **system monitor** (CPU/RAM/temp/disk/GPU/network) is the single
  **`sysmon`** widget. (nebula's live config also carries a `[widget.cpu]` table
  with `display = "graph"`; treat `sysmon` as the canonical addable id and
  confirm exact ids in the Settings "add widget" list if unsure.)
- There is **no standalone `microphone` widget** — mic is handled by `volume`
  (PipeWire output+input) and surfaced in `privacy`.
- **`screen_recorder` is an official plugin, not a built-in bar widget.**
- `custom_button` runs commands: `glyph`, `tooltip`, `command`, `right_command`,
  `middle_command`, `scroll_up/down_command` (commands can be `noctalia:<ipc>`).

**nebula's bar** (`[bar.bar]`, bottom): `center = ["media"]`; `end = ["tray",
"notifications", "clipboard", "network", "volume", "control-center",
"group:g1"]` where capsule group `g1` = `["clock", "session"]`.

### Panels (for `panel-open` / `panel-toggle` / `panel-close <id> [context]`)

Authoritative id list (from the binary's own error message):
**`clipboard`, `control-center`, `launcher`, `polkit`, `session`,
`setup-wizard`, `test`, `tray-drawer`, `wallpaper`** (`polkit`/`setup-wizard`/
`test` are internal).

- **`settings` is NOT a panel** — use `settings-open`/`-close`/`-toggle`.
- Calendar / notifications / audio / network / wifi / bluetooth are **Control
  Center tabs (contexts)**, not separate panels.
- **`[context]`** is a panel hint: for the launcher it's a provider query (e.g.
  `panel-toggle launcher "/wall"`); for control-center it's a tab name (e.g.
  `panel-toggle control-center media`).

### Launcher providers / prefixes

`AppProvider` (no prefix, default), calculator/`MathProvider` (no prefix, via
`libqalculate` — arithmetic + unit/currency conversion), and slash-prefixed
providers confirmed in the binary: **`/emo`** (emoji), **`/wall`** (wallpaper),
**`/win`** (windows), **`/session`**. `/clipboard` and `/brightness` tokens also
appear; the translator plugin adds `/tr`.

### Dock / desktop widgets / lockscreen widgets / window switcher

- **Dock** is `enabled = false` by default (see `[dock]` keys above).
- **Desktop widgets** (`[desktop_widgets]`, off by default): coordinate-placed,
  not a grid layout — each `[desktop_widgets.widget.<id>]` has `type`, `output`,
  `cx`/`cy`, `box_width`/`box_height`, `rotation`, scale, and a `.settings`
  sub-table; an optional `[desktop_widgets.grid]` is just an editor overlay
  (snap guides). Types: `clock`, `weather`, `media_player`, `sysmon`,
  `audio_visualizer`, `fancy_audio_visualizer`, `button`, `sticker`, `label`.
  Edit live with `noctalia msg desktop-widgets-edit` (and `-show`/`-hide`/
  `-toggle`/`-toggle-edit`/`-exit`).
- **Lockscreen widgets** (`[lockscreen_widgets]`): symmetric; e.g. `login_box`
  (id like `lockscreen-login-box@DP-3`). Editor: `noctalia msg
  lockscreen-widgets-edit`.
- **Window switcher** is its own IPC verb, not a panel: `noctalia msg
  window-switcher [close]`.

## IPC reference (`noctalia msg <command>`)

The day-to-day control surface. `noctalia msg --help` is authoritative; grouped
here. Many commands persist to `settings.toml`; the `desktop-widgets-*`
visibility ones are explicitly runtime-only.

- **Panels/UI:** `panel-open|panel-toggle|panel-close <id> [context]`,
  `settings-open|-close|-toggle`, `window-switcher [close]`, `status` (→ JSON
  `{barVisible, panelOpen, activePanelId}`).
- **Bar:** `bar-show|bar-hide|bar-toggle [bar-name] [monitor-selector]`,
  `bar-auto-hide-set <on|off> [bar-name] [monitor-selector]`.
- **Dock:** `dock-show|-hide|-toggle|-reload`.
- **Desktop/lockscreen widgets:** `desktop-widgets-{edit,exit,hide,show,toggle,
  toggle-edit}`, `lockscreen-widgets-{edit,exit,toggle-edit}`.
- **Theme:** `theme-mode-get|-set <dark|light|auto>|-toggle`,
  `color-scheme-get`, `color-scheme-set <source> <name>` (source =
  `builtin|wallpaper|community|custom`; for `wallpaper`, name = a scheme like
  `m3-rainbow`), `templates-apply`, `config-reload`.
- **Wallpaper:** `wallpaper-get [<connector>]`, `wallpaper-set [<connector>]
  <path>`, `wallpaper-random [<connector>]`.
- **Audio:** `volume-up|-down [step]`, `volume-set <0-100|0.0-1.0>`,
  `volume-mute`, `mic-mute`, `mic-volume-up|-down|-set`, `media <next|previous|
  toggle|stop>`, `effects-profile-set <output|input> <profile>` (EasyEffects).
- **Brightness:** `brightness-up|-down [target] [step]`, `brightness-set
  [target] <value>`, `brightness-osd <value>` (target/selector =
  `current|*|all|<connector>`).
- **Network:** `wifi-enable|-disable|-status|-toggle`, `bluetooth-enable|
  -disable|-status|-toggle`.
- **Power/idle/session:** `power-cycle`, `power-set <performance|balanced|
  power-saver>`, `caffeine-enable|-disable|-toggle`, `dpms-on|-off`,
  `session <lock|suspend|lock-and-suspend|logout|reboot|shutdown>`.
- **Night light:** `nightlight-enable|-disable|-toggle|-force-toggle`.
- **Notifications:** `notification-clear-active|-clear-history`,
  `notification-dnd-set <on|off>|-status|-toggle`.
- **Clipboard:** `clipboard-clear`.
- **Screenshot:** `screenshot-region`, `screenshot-fullscreen [pick|monitor|all]`.
- **Misc:** `greeter-sync`, `screen time` is config-driven (no verb).
- **Plugins:** `plugins <list|enable|disable|update|source list/add/remove> …`,
  `plugin <author/plugin:entry> <target[:bar-name]> <event> [payload]`.

## Features / integrations (and their backends)

Verified backends (machine + docs); the genuinely native pieces matter for the
Nix dependency list:

| Feature | Backend on v5 |
|---|---|
| Color generation | **native** (vendored Material Color Utilities) — *no matugen* |
| Audio (volume/mic/visualizer) | **PipeWire**; shells out to **`wpctl`** (WirePlumber). *No cava.* |
| Media controls | **native MPRIS** over D-Bus (`libsdbus-c++`) — *no playerctl* |
| Clipboard history | **native** store (`~/.local/state/noctalia/clipboard/`) — docs say "cliphist" but the live store is Noctalia's own |
| Brightness | kernel **backlight** + optional **`ddcutil`** (external monitors, gated by `brightness.enable_ddcutil`) — *brightnessctl not used* |
| Screenshots | **native** Wayland screencopy — *no grim/slurp* (mechanism inferred; not upstream-cited) |
| Screen recorder | **official plugin** (`gpu-screen-recorder`), not built in |
| Night light | gamma control (`wlr-gamma-control` family) |
| Idle / caffeine | `ext_idle_notifier_v1`, respects inhibitors |
| Network / Bluetooth | **NetworkManager** + BlueZ |
| Power profiles | **UPower** + **power-profiles-daemon** |
| Weather | location service (provider not named upstream; likely Open-Meteo) |
| Polkit agent | `libpolkit-agent-1` (opt-in `[shell].polkit_agent`) |
| Greeter | separate **noctalia-greeter** (greetd); `greeter-sync` |

## Plugins

A v5 plugin system is **planned / under active development** — treat it as early.

- Plugins are **Luau** scripts + a `plugin.toml` manifest with entry-type tables
  (`[[widget]]`, `[[desktop_widget]]`, `[[shortcut]]`, `[[service]]`,
  `[[launcher_provider]]`), each in its own isolated Luau VM. This supersedes the
  old QML/`manifest.json` v4 scheme.
- **Sources** (git repos cloned to `~/.local/state/noctalia/plugins/sources/
  {official,community}/`): official = `noctalia-dev/official-plugins`, community =
  `noctalia-dev/community-plugins` (currently effectively empty / "coming soon").
- **Manage:** `noctalia msg plugins <list|enable|disable|update|source
  add/remove>`. **Dispatch an event:** `noctalia msg plugin <author/plugin:entry>
  <target> <event> [payload]` (target = `focused | <connector>[:<bar-name>] |
  all`), firing the entry's `onIpc`.
- Official plugins that ship: `example`, `screen_recorder`, `bongocat`,
  `translator` (`/tr` launcher provider), `timer` (desktop widget).

## nebula wiring (Hyprland)

In `home/hyprland/.config/hypr/hyprland.lua`:

- **Autostart** (in the `hyprland.start` hook): `hl.exec_cmd("pkill -x noctalia;
  noctalia --daemon")` — replaces any stale instance from a session restart.
- **Wallpaper:** Noctalia paints it; **no hyprpaper** (removed, commit 47290cd).
- **Color template load:** `require("noctalia")` at the bottom of the file pulls
  in the generated `~/.config/hypr/noctalia.lua` (border colors from the palette).
- **Keybinds:**
  - `SUPER + space` → `noctalia msg panel-toggle launcher`
  - `SUPER + N` → `noctalia msg panel-toggle control-center`
  - `SUPER + L` → `noctalia msg session lock`
  - (`SUPER + D` stays on fuzzel.)
- **Blur layerrule** for the shell surfaces (translucency reads against the
  wallpaper): a rule named `noctalia-blur` matching namespace
  `noctalia-background-.*$`. **Caveat (verify before trusting):** the docs' real
  v5 layer namespaces are `noctalia-bar-*`, `noctalia-notification`,
  `noctalia-dock`, `noctalia-panel`, `noctalia-osd`, and backgrounds
  `noctalia-backdrop` / `noctalia-wallpaper` — **not** a literal
  `noctalia-background-*`. Confirm with `hyprctl layers` on the live session and
  fix the match if blur isn't applying. (Pair blur with each surface's
  `background_opacity`.)

## noctalia.nix dependency cleanup (applied 2026-06-19)

`modules/hosts/nebula/users/k/noctalia.nix` used to carry five **v4-era runtime
tools that v5 doesn't reference** (confirmed by `strings` on the binary). All
five were removed from the Noctalia user-package list — it now declares only the
`noctalia` package plus the surfaced services:

- **`matugen` — removed.** v5 vendors Material Color Utilities; matugen is absent
  from the binary and closure. Only `noctalia.nix` declared it → gone entirely.
- **`cava` — removed.** Absent from the binary; the audio visualiser is native
  PipeWire/`wpctl`. (`cava` survives only as a *theme template* for the cava app,
  which doesn't need the cava binary.) Only `noctalia.nix` declared it → gone.
- **`cliphist`, `wl-clipboard`, `brightnessctl` — removed from `noctalia.nix`,
  still present system-wide.** v5 has native clipboard history + brightness, so
  Noctalia doesn't need them — but the **niri/Hyprland keybinds do** (cliphist
  clipboard pipeline, `XF86MonBrightness*` binds). They remain in the system
  profile via `configuration.nix` `environment.systemPackages` (cliphist) and
  snowglobe's desktop module (wl-clipboard, brightnessctl), so dropping them from
  k's user packages is a **no-op** for those binds. Verified: after the rebuild,
  `wl-copy`/`wl-paste`/`brightnessctl`/`cliphist` are still in
  `/run/current-system/sw/bin`.

`wpctl` (WirePlumber, what audio control shells out to) is provided by the
PipeWire stack, not this list — untouched.

## External-monitor brightness via DDC/CI (enabled 2026-06-19)

nebula's monitors are DP outputs with **no kernel backlight** (`/sys/class/
backlight` is empty), so brightness only works over **DDC/CI** on the I²C bus.
Now wired up:

- `noctalia.nix` adds **`pkgs.ddcutil`**, **`hardware.i2c.enable = true`** (loads
  `i2c-dev` declaratively, creates the `i2c` group + udev rules), and
  **`users.users.k.extraGroups = [ "i2c" ]`**.
- `~/.local/state/noctalia/settings.toml` sets **`[brightness] enable_ddcutil =
  true`** (validated + `config-reload`ed; appears in `noctalia config export
  merged`).

**Access note:** k already held a per-session **logind ACL** on `/dev/i2c-*`
(`getfacl` → `user:k:rw-`), so DDC worked even before the `i2c` group; the group
is the durable fallback (effective after next login).

**DDC/CI verified working on the NVIDIA buses** (the one real risk) — `ddcutil
detect` finds both monitors and brightness (VCP `0x10`) reads/writes:

| Display | I²C bus | Monitor | VCP | Brightness 0x10 |
|---|---|---|---|---|
| DP-1 | `/dev/i2c-6` | ASUS ROG PG348Q | 2.2 | 50/100 |
| DP-3 | `/dev/i2c-8` | ASUS PG34WCDM | 2.2 | 87/100 |

(`ddcutil`'s `-EIO for unsupported features` line is a generic caveat about
*other* VCP features, not brightness.)

**The Control Center brightness slider is confirmed working (2026-06-19).**
nebula's bar has no `brightness` widget, so the slider lives in the **Control
Center** (`SUPER+N`); dragging it changes both monitors over DDC. The
`XF86MonBrightness*` hardware keys are
still bound to `brightnessctl` in `hyprland.lua` — a **no-op on DP** (no
backlight); rebind them to `noctalia msg brightness-up|-down [step]` if you want
the hardware keys to drive DDC too.

## Learned behaviours & workarounds

- **Editing `settings.toml` IN PLACE while Noctalia runs corrupts it — write
  ATOMICALLY (2026-06-19, cost ~an hour).** Symptom: after an in-place edit
  (`sed -i`, or a tool that opens/truncates/rewrites the existing inode) followed
  by `noctalia msg config-reload` *or* a restart, `settings.toml` was destructively
  rewritten down to a **single `[lockscreen_widgets]` table** — the other 16
  sections (`[shell]`, `[theme]`, `[bar]`, …) vanished. Noctalia watches the file;
  when it sees the change it kicks off a save that (in v5.0.0) clobbers the whole
  file with one subsystem's data. Proven by isolation: `config-reload` on an
  *unchanged* file is safe (file stays intact); a plain `cp` of identical content +
  restart is safe; an in-place value change + reload/restart truncates to 42 lines.
  **Fix: never edit the live file in place.** Write a complete new file in the
  *same directory* and `mv -f` it over the target (atomic rename → the watcher
  only ever sees a finished inode). With an atomic swap, `noctalia msg
  config-reload` then applies the change **live and non-destructively** — no
  restart needed. The Hyprland gaps toggle edits with **`tomato`** (`pkgs.tomato`,
  packages/tomato.nix — Rust `toml_edit`, comment/format-preserving), but because
  `tomato set` writes IN PLACE, the toggle script copies settings.toml to a
  same-dir temp, runs `tomato` on the copy, then `mv -f`s it in. **Always keep a
  backup before touching settings.toml** (it's not in the dotfiles repo; it lives
  in `~/.local/state/noctalia/`).
- **`[shell.screen_corners]` is GLOBAL, no per-monitor option (2026-06-19).** It
  paints a rounded-corner black overlay on every output's screen edges (keys:
  `enabled`, and a corner-radius `size`). There's **no IPC command** to toggle it
  (`noctalia msg` has none for corners) — the only lever is `enabled` in
  settings.toml + `config-reload`. The Hyprland "toggle gaps" keybind ties it to
  the gaps state (gaps off → corners off so windows go truly edge-to-edge; gaps on
  → corners on); because it's global, that flips corners on *all* monitors, not
  just the toggled one. See docs/hyprland.md and home/hyprland/.config/hypr/
  scripts/toggle-gaps.sh.
- **v5 ≠ Quickshell (2026-06-19).** The biggest trap. v4 was Quickshell/QML; v5
  is native C++/Wayland/GLES. Don't apply v4 advice (`qs -c noctalia-shell`, QML
  plugins, JSON `settings.json` with `schemaVersion`, `~/.config/noctalia/
  settings.json`). DeepWiki and the AUR description still document v4 — ignore
  them for v5. Verified via `ldd`/`strings` on the binary.
- **Config is TOML and lives in TWO places (2026-06-19).** Hand-written
  `~/.config/noctalia/*.toml` (merged alphabetically) is the *base*; GUI/IPC
  writes `~/.local/state/noctalia/settings.toml`, which **wins**. On nebula the
  config-home is empty, so *every* setting is in state-home. Editing a config.toml
  won't override a GUI-set key with the same name.
- **No `restart` subcommand (2026-06-19).** Second launch refuses with `error:
  noctalia is already running` (exit 0). Restart = `pkill -x noctalia; noctalia
  --daemon`. `config-reload` handles most edits live; restart for structural
  changes (e.g. adding a bar). The FR for a built-in restart was closed
  *not planned*.
- **Output disable/re-enable loses Noctalia surfaces (cross-ref `hyprland.md`).**
  After a monitor disable→re-enable under Hyprland, Noctalia may not recreate its
  wallpaper/bar on that output — restart it (`pkill -x noctalia; noctalia
  --daemon`).
- **`noctalia.lua` is generated (2026-06-19).** The Hyprland color template
  writes `~/.config/hypr/noctalia.lua` (real dir, not the stow tree) and injects
  `require("noctalia")`. Don't hand-edit `noctalia.lua`; change colors via the
  theme/palette instead. Re-render with `noctalia msg templates-apply`.
- **matugen/cava are not v5 deps (2026-06-19).** See *Recommended cleanup* — both
  confirmed absent from the v5 binary.
- **Template id `gtk`/`kde` vs `gtk3`/`gtk4`/`kcolorscheme` (2026-06-19).** Older
  pinned asset trees shipped single `gtk`/`kde`; the installed build splits them.
  Always read live ids from `noctalia theme --list-templates`, not the source
  asset dir.
- **Layer namespaces for blur are uncertain (2026-06-19).** Our `hyprland.lua`
  matches `noctalia-background-.*`; docs suggest the real namespaces differ
  (`noctalia-bar-*`, `noctalia-wallpaper`, `noctalia-backdrop`, …). If blur
  doesn't apply, run `hyprctl layers` to read the actual namespaces and fix the
  rule.
- **Doc/build version mismatch (2026-06-19).** The binary self-reports `v5.0.0`
  while upstream still calls v5 "alpha" with no `v5.0.0` *release* tag. The
  install is branch HEAD at a pinned commit, so re-verify everything after
  `nix flake update`.

## Sources

- Upstream repo (canonical) — <https://github.com/noctalia-dev/noctalia>
  (input resolves via `github:noctalia-dev/noctalia-shell`, which redirects);
  Codeberg mirror <https://codeberg.org/noctalia-dev/noctalia-shell>.
- Docs — <https://docs.noctalia.dev/v5/> (getting-started/installation &
  /nixos, configuration/*, bar/widgets, theming, ipc/*, desktop/widgets,
  plugins). v4 archive under `/v4/`.
- Site / Discord — <https://noctalia.dev> · <https://discord.noctalia.dev>.
  Greeter — <https://github.com/noctalia-dev/noctalia-greeter>.
- Pinned source @ `28a38bf` — `flake.nix`, `nix/{package,home-module,
  hjem-module,devshell}.nix`, `meson.build`, `example.toml`,
  `assets/templates/builtin.toml` + `hyprland/`.
- Machine-verified on nebula, **2026-06-19**: `noctalia --version|--help`,
  `noctalia msg --help|status|color-scheme-get`, `noctalia theme --help|
  --list-templates`, `noctalia config --help|validate`, `ldd`/`strings` on the
  installed binary, and `~/.local/state/noctalia/settings.toml`.
- v4→v5 delta — the v5 announcement on <https://noctalia.dev/blog> + README
  (there is no formal v5 changelog yet; last v4 release v4.7.7, 2026-05-13).
