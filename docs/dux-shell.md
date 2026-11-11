# Dux Shell manual (nebula)

A working reference for **Dux Shell**, nebula's Wayland desktop shell under
Hyprland since 2026-11-03, replacing [Noctalia](noctalia.md). Distilled from
the upstream docs (<https://github.com/duxlabs-dev/dux-docs>, `versioned_docs/version-2.0`)
and the shipped source, and checked against this machine's build. Maintained for
Claude's use: keep it accurate, prune anything that stops being true, and record
real gotchas in **Learned behaviours & workarounds** at the bottom.

## Version & state on nebula (read this first)

- **Package:** `dux-shell` **2.1.1**, straight from nixpkgs since the
  2026-11-10 lock update (the 2.1.0 override in `dux-shell.nix` is gone). It's
  on nixpkgs `quickshell` **0.3.2**, which is the minimum 2.1.0's
  `dms doctor` accepts, plus `matugen` 4.2.0 and `cava`. 2.1.0
  added **video wallpapers** (mp4/webm/mkv/mov/m4v/avi via QtMultimedia, which
  is already in the wrapper's QML path). Their poster frames are extracted
  with `ffmpeg`, found on `dms.service`'s PATH through k's profile. GIF and
  animated WebP still show only their first frame (no `AnimatedImage`), so
  convert them to webm/mp4 to animate them.
- **Patched:** `overlays/dux-shell.nix` applies
  `dux-shell-tray-menu-coords.patch` (tray context-menu coordinates, see
  Learned behaviours 2026-11-10). It is cut against 2.1.0 and still
  applies to 2.1.1: re-cut or drop it on a version bump. It also applies
  `dux-shell-dock-wine-editions.patch` (a dock icon per edition of a Wine
  game, see Learned behaviours 2026-11-11), cut against 2.1.1.
- **Formerly DankMaterialShell ("DMS").** v2.0.0 (2026-10-20) moved the project
  to Dux Labs and renamed the repos/packages, but the CLI is still **`dms`**,
  the unit **`dms.service`**, the app ID `dev.duxlabs.shell`. nixpkgs keeps
  `dms-shell` / `programs.dms-shell` as renamed aliases.
- **Verified 2026-11-03:** eval + `nrb` build, live Hyprland config reload with
  no `configerrors`, all binds registered. **Running since gen 219**
  (2026-11-03 19:00): `dms.service` active at ~490 MB RSS (Noctalia v5 was
  ~232 MB), owns `org.freedesktop.Notifications`, polkit agent registered, bars
  on DP-1 + DP-3, `dms doctor` all green (run with the session env — see below).
  **2026-11-04:** per-display wallpapers (DP-1 portrait, DP-3 landscape) and
  the Wallpaper Sets plugin verified live: IPC, Dash tab save/apply/remove,
  keyboard + pointer. **2.1.0 running since gen 224:** an mp4 on DP-3 plays
  (Quickshell holds the file open, with Qt's ffmpeg media plugin and
  libavcodec loaded, and the wallpaper pixels change over time). Its poster
  frame landed in `~/.cache/dms/video-wallpaper/`. A mixed video + image set
  saves, shows the poster with a movie badge, and switches by click,
  `apply`, `next` and `prev`. Still to check: lock/unlock, workspace bar
  over time.

## What it is

A Quickshell/QML shell (bar, launcher "spotlight", control centre, dashboard,
notifications, lock screen, idle/suspend, clipboard history, OSDs, dock,
wallpaper + matugen theming, polkit agent, settings GUI) plus a Go `dms`
binary that is both the CLI and the backend daemon (IPC, system monitoring,
screenshots, PAM resolution, theme generation, plugin installs). Pick
rationale: [knowledge/decisions/dux-shell-replaces-noctalia.md](../knowledge/decisions/dux-shell-replaces-noctalia.md).

## How it is wired

| Piece | Where | Notes |
| --- | --- | --- |
| Package + service | `modules/hosts/nebula/users/k/dux-shell.nix` | `programs.dux-shell.enable` (nixpkgs module). Also adds matugen + cava to systemPackages, mkDefaults accounts-daemon / i2c / graphics on. |
| Startup | `dms.service` (user) | `dms run --session`, `Type=notify`, `Restart=on-failure`, WantedBy `graphical-session.target` (uwsm reaches it). Not in `autostart.lua`. |
| Polkit agent | Dux's own | `hyprpolkitagent`'s `wantedBy` is forced empty while Dux is on (a session takes one agent). Escape hatch: `DMS_DISABLE_POLKIT=1`. |
| Shared plumbing | `modules/hosts/nebula/users/k/desktop-shell.nix` | upower, power-profiles-daemon, bluetooth, swaync **off** (Dux owns `org.freedesktop.Notifications`), the bare-name `/etc/pam.d/login`, DDC/CI (i2c + ddcutil). |
| Border colours | `home/hyprland/.config/hypr/hyprland.lua` | `require("dms.colors")` behind a `package.searchpath` guard (file is generated, may be absent), then `noctalia-overrides.lua` (historical name) re-darkens `inactive_border` for ghostty. |
| Layer rule | `window-rules.lua` | `dms-no-anim`: `no_anim` on namespaces `^dms` (upstream recommendation). Blur needs no rule on 0.56+ (ext-background-effect-v1, toggled in Settings). |

Two fragments are loaded: **colors** (from `hyprland.lua`) and **outputs**
(from `monitors.lua`, filtered; see below). Dux's other Hyprland fragments
(`layout`, `cursor`, `input`, `binds`, `binds-user`, `windowrules` under
`~/.config/hypr/dms/`) would fight `look-and-feel.lua`, `input.lua` and
`keybindings.lua`, which own those here. Dux's Settings pages for Hyprland
layout, input, keybinds and window rules therefore look editable, but what
they save lands in unloaded fragments: it never takes effect, or is undone at
the next reload. Some pages also offer a "Setup" banner (see below).

### Displays (Settings → Displays)

Dux owns the monitor setup (position, scale, rotation, mode, VRR, bit depth,
colour management), with
[decision](../knowledge/decisions/dux-owns-monitor-layout.md). Apply writes
`~/.config/hypr/dms/outputs.lua` and runs `hyprctl reload`. `monitors.lua`
sets baseline rules first, then loads that file through a wrapped
`hl.monitor`:

- **Set "Name format" to Model** (once). Only `desc:` rules are taken.
  Connector-named rules (`DP-3`) and Dux's empty-name catch-all are ignored,
  so with "Name" Dux has no effect. Connector numbers change across boots
  here.
- **OLED guards** stop the two settings that blank the PG34WCDM:
  `cm = "auto"` (or omitted, which is Dux's "Auto") becomes `"srgb"`, and a
  rate above 144 Hz, `preferred`, or a bare `WxH` becomes `3440x1440@143.97`.
  Any non-sRGB `cm` without a bit depth gets `bitdepth = 10`. Everything else
  is kept, including HDR modes (`hdr`, `hdredid`), which are only cosmetic
  risks.
- Dux's rules **replace** the baseline whole: Hyprland keeps one rule per
  output name, and the last match wins. A field Dux omits is not filled from
  the baseline.
- No Dux file (fresh home, shell never run), or a broken one: the baseline
  layout applies (DP-3 at 1440x1581), and a broken file also shows in
  Hyprland's config-error banner.

## Keybinds (keybindings.lua)

| Bind | Command |
| --- | --- |
| SUPER+Space | `dms ipc call spotlight toggle` (launcher; fuzzel stays on SUPER+D) |
| SUPER+N | `dms ipc call control-center toggle` |
| SUPER+Comma | `dms ipc call settings focusOrToggle` |
| SUPER+L | `dms ipc call lock lock` |
| Print | `dms screenshot` (region) |
| ALT+Print | `dms screenshot window` |
| CTRL+Print | `dms screenshot full` (focused output) |
| CTRL+SHIFT+Print | `dms screenshot all` (all outputs) |

Volume/brightness/media keys still call `wpctl` / `brightnessctl` /
`playerctl` directly; Dux's OSD reacts to the resulting changes. Discover
every IPC target with `dms ipc list` (needs the shell running).
`dms screenshot` is a standalone Go command with its own region selector, so
it works even when the shell is down; by default it saves a file **and**
copies to the clipboard (`--no-file` / `--no-clipboard`).

## First session after `nrs`

The switch installs Dux but does not hand the session over by itself:

```sh
pkill noctalia                        # frees the notifications name + wallpaper (NOT -x; see below)
systemctl --user stop hyprpolkitagent # Dux's agent takes over
systemctl --user restart dms          # (re)start so it claims both
dms doctor                            # sanity report
```

(A logout/login does the same.) Then in Settings (SUPER+Comma):

- **Wallpaper & colors:** turn on **"Separate per display"** (it's off by
  default, so every display shows the global wallpaper), then use the
  **Display** dropdown that appears at the top of Appearance to pick an image
  for each one. Noctalia's per-monitor folders are not imported. This also
  generates `~/.config/hypr/dms/colors.lua`. See
  [Per-display wallpapers & sets](#per-display-wallpapers--sets).
- **Lock Screen → Authentication:** leave **Auto**, or choose **Use system PAM
  authentication** (`/etc/pam.d/login` directly). Test lock (SUPER+L) and unlock.
- **Interface style → Surfaces → Background blur:** optional.

## Per-display wallpapers & sets

Dux stores a wallpaper for each display itself (`SessionData.monitorWallpapers`,
in `~/.local/state/dms/session.json`). Besides the Settings toggle above:

- `dms ipc call wallpaper setFor DP-1 <path>`: sets one display, and turns on
  per-display mode if it's off. The same target has `getFor`, `nextFor` and
  `prevFor`. Per-display cycling, with its own folder for each display, is
  in the cycling settings once per-display mode is on.
- The Dash **Wallpapers** tab only sets the display the dash is open on.
- **Matugen source display** (Settings → Wallpaper, shown in per-display
  mode) picks which display's image drives the theme colours. Unset means
  the first screen.

Dux can't save a combination and switch back to it, so the repo adds the
**Wallpaper Sets** plugin (`wallpaperSets`,
[decision](../knowledge/decisions/dux-wallpaper-sets-plugin.md)). It is the
stow package `home/dux-shell/` → `~/.config/dms/plugins/WallpaperSets/`,
which is live-editable.

- **Dash tab "Wallpaper Sets"** (`dms ipc call dash open plugin_wallpaperSets`)
  shows the current displays with a name field. Save stores them as a set;
  an existing name updates that set. Clicking a set applies it, the trash
  icon removes it, and the active set is ticked.
- **IPC:** `dms ipc call wallpaperSets list` (the active set is marked `*`),
  plus `current`, `show <name>`, `apply <name>`, `save <name>`,
  `remove <name>`, `next` and `prev`.
- Sets and the enabled flag are kept in `~/.config/dms/plugin_settings.json`
  (untracked) under `wallpaperSets`.
- **New machine / fresh config:** `dms ipc call plugins enable wallpaperSets`.
  Composite plugins don't load until they're enabled.
- **After editing the QML:** `dms ipc call plugins reload wallpaperSets`.
  **After editing `sets.js`:** `systemctl --user restart dms`. A reload does
  not pick up JS changes; see Learned behaviours.
- **Video sets (2.1+):** a set can hold video paths like any other wallpaper,
  since saving and applying just pass paths to Dux. Each tile shows Dux's
  poster frame (`VideoWallpaperService.imageFor`) with a movie badge.
  Guarded with `typeof`, so the plugin still works on 2.0.

## Do not

- **Run `dms setup`.** It writes a fresh `hyprland.lua` (backing up the old one)
  and refreshes `binds.lua` — `hyprland.lua` is a stow symlink into this repo.
- **Click a Settings "Setup" banner.** The repair script appends
  `require("dms.<fragment>")` lines with `>>` to `hyprland.lua` — through the
  symlink, into the repo copy — for exactly the fragments excluded above.
- **Change the icon theme away from "System Default".** Dux applies it with
  `sed -i` on `~/.config/gtk-{3,4}.0/settings.ini`, which are stow symlinks
  (`home/gtk/`); `sed -i` replaces a symlink with a plain file, and a plain file
  at a stow target aborts the whole `gtk` package on the next rebuild.
- **Install registry plugins casually.** Plugins are git-cloned third-party QML,
  unsigned and unsandboxed; they run as you. Prefer the declarative
  `programs.dux-shell.plugins.<name>.src` (pinned store paths) if you want one.

Theme files Dux *creates* are fine — they are new files, never the tracked ones:
`~/.config/ghostty/themes/dankcolors`, `~/.config/gtk-{3,4}.0/dank-colors.css`,
`~/.config/nvim/colors/dms.lua`, `~/.config/qt{5,6}ct/colors/matugen.conf`, etc.
Ghostty still uses `theme = noctalia` (the last Noctalia-generated file stays on
disk); switching it to `dankcolors` in `modules/nixos/ghostty.nix` is optional.

## State & config locations

- Settings: `~/.config/dms/settings.json` (pre-2.0: `~/.config/DankMaterialShell/`,
  auto-migrated). Not tracked in the repo yet.
- Per-display wallpapers, cycling state: `~/.local/state/dms/session.json`.
- Plugins: `~/.config/dms/plugins/` (ours is stow-linked from
  `home/dux-shell/`); plugin enable flags and data:
  `~/.config/dms/plugin_settings.json`; plugin state:
  `~/.local/state/dms/plugins/`. Nix-installed plugins:
  `/etc/xdg/quickshell/dms-plugins/`.
- Generated Hyprland fragments: `~/.config/hypr/dms/`.
- Lock-screen PAM (Auto mode): `~/.local/state/dms/pam/`.
- Cache (colors JSON, clipboard DB): `~/.cache/dms/`.

## Known issues (2026-11-03)

- **Lock crash-loop when outputs power off on lock** — upstream #4103, opened
  against Hyprland 0.57. A crashed locker leaves the session locked (Hyprland's
  ext-session-lock fallback), it does not unlock. If hit, avoid
  `lock lockAndOutputsOff` and any idle setting that powers monitors off
  right after locking.
- **Quickshell 0.3.2 predates `4befab5` "hyprland/ipc: follow workspace id
  changes"** (2026-10-16). Dux reads workspaces through `Quickshell.Hyprland`,
  so a workspace whose id Hyprland changes (`changeworkspaceid`) can keep its
  old id in the bar. Fix if seen: point `programs.dux-shell.quickshell.package`
  at a quickshell git build.

## Switching back to Noctalia

1. `modules/hosts/nebula/users/k/noctalia.nix`: `enable = true`.
2. `modules/hosts/nebula/users/k/dux-shell.nix`: `programs.dux-shell.enable = false`
   (this also restores `hyprpolkitagent`).
3. Hyprland Lua — restore from git (the commit that introduced this doc):
   `autostart.lua` (`noctalia --daemon`; its old `pkill -x noctalia` never
   matched — use `pkill noctalia`), `hyprland.lua`
   (`require("noctalia").apply_theme()` behind the searchpath guard),
   `keybindings.lua` (`noctalia msg …` binds, SUPER+SHIFT+W wallpaper re-apply,
   the toggleGaps screen-corner sync, ALT+Print grim grab), `window-rules.lua`
   (`noctalia-blur` layer rule).
4. `nrs`, then `systemctl --user stop dms; noctalia --daemon` (or re-login).

## Learned behaviours & workarounds

- **2026-11-11 — One dock icon for every WoW edition (patched).** The dock
  finds a window's icon through `DesktopEntries.heuristicLookup(appId)`,
  which matches a desktop entry's id or `StartupWMClass` (hidden
  `NoDisplay` entries too, and it picks up new entries live). Wine's
  Wayland driver sets the app id to the exe's name, so WoW retail
  (`_retail_\Wow.exe`) and WoW: Forever (`_forever_\Wow.exe`) are both
  `wow.exe`, and nothing in Wine or Hyprland can change that.
  `overlays/dux-shell.nix` patches `DockAppButton.qml`: for an app id
  ending in `.exe` it takes the window's pid from
  `Hyprland.toplevels` (`lastIpcObject.pid`), reads
  `/proc/PID/cmdline` with a blocking `FileView`, and if the path has a
  `\_<edition>_\` directory it looks up `<name>-<edition>.exe`
  (`wow-forever.exe`) before the plain app id. `flakes/battlenet` ships
  the entries and icons. Dock only: the bar's running-apps widget and the
  window switcher still use the app id. A grouped dock button takes its
  first window's edition.
- **2026-11-10 — A tray icon's own menu opened a screen away (patched).**
  Battle.net's tray menu (Wine's Wayland driver; a `wine-menu` layer
  surface, not a window, so no Hyprland rule can move it) opened at the top
  of DP-3 with the bar at the bottom. An icon with no D-Bus menu
  (`hasMenu` false) gets `StatusNotifierItem.ContextMenu(x, y)` in screen
  coordinates, and `SystemTrayBar.qml` took them from `mapToGlobal()`. For
  a layer-shell window that is the screen origin plus the position inside
  the window (checked with a 4 px probe panel: `1540,1365` for an item at
  `100,2` on DP-3 at `1440,1363`), so y was the offset inside the 44 px
  bar. `overlays/dux-shell.nix` patches the two callers to add screen size
  minus bar-window size on the bottom and right edges. Sending Wine the
  true point by hand (`busctl --user call <bus> /StatusNotifierItem
  org.kde.StatusNotifierItem ContextMenu ii 3566 2785`) put the menu's
  bottom-left corner on it. Not patched: the overflow popout and island
  callers. Not yet reported upstream.
- **2026-11-04 — Displays "Setup" banner = Dux can't see the include.** The
  banner runs `dms config resolve-include hyprland outputs.lua`, which follows
  `require`s from `hyprland.lua` but only matches the literal call form
  `require("dms.outputs")` (`core/internal/luaconfig/lua.go`).
  `pcall(require, "dms.outputs")` looked "not included", so Setup appended a
  raw `require("dms.outputs")` to `hyprland.lua` (the repo copy, through the
  symlink). That copy only did nothing because Lua had already cached the
  module. `monitors.lua` now uses `pcall(function() require("dms.outputs") end)`.
  Check with that command; it should print `"included":true`.
- **2026-11-04 — Per-output colour settings are keyed by name format.**
  `session.json` → `hyprlandOutputSettings` stores 10-bit/cm under the
  identifier current when they were set (`DP-3` in "Name" mode, `desc:…` in
  Model mode), and Model mode looks up `desc:…` first. After switching format,
  re-check the OLED's bit depth/colour in Settings → Displays.

- **2026-11-04 — Dux carries forward rules it finds in `outputs.lua`.** On
  Apply it re-reads the existing file and writes back every entry it parsed,
  not just the live outputs. A rule staged for testing (here, `desc:` rules
  in "Name" mode) therefore came back at the next Apply, and since only
  `desc:` rules are loaded, it pinned the layout. Don't leave hand-written
  lines in that file; if one sneaks in, delete it and `hyprctl reload`.

- **2026-11-04 — Display moves "snapped back".** Apply in Settings → Displays
  writes `dms/outputs.lua` and then runs `hyprctl reload`. Before the
  `monitors.lua` rework, the reload re-ran a hard-coded position and never
  read Dux's file, so every move was undone within a second. Source:
  `Services/HyprlandService.qml` (`writeOutputsConfig` → `reloadConfig`). In
  `hyprctl monitors -j`, `make model serial` is exactly the string Dux's
  Model mode puts after `desc:`.

- **2026-11-04 — `nrs` restarts the shell when the package changes.** The
  switch reloads k's user units and stops and starts `dms.service` itself
  ("stopping (user) dms.service … starting (user) dms.service"), so a Dux
  bump is live straight after `nrs`. Apps survive, as with any restart.
  First run of 2.1.0 opens a "What's New" window and a Settings window, and
  the Dash got wider (928 px on DP-3).

- **2026-11-04 — `plugins reload` keeps the old JS libraries.** It reloads a
  plugin's QML (as `…qml?revision=N`), but a `.pragma library` JS import
  resolves to the plain file URL, which the QML engine has already cached for
  the life of the process. A new function in `sets.js` then shows up as
  "TypeError: Property 'x' … is not a function". Restart `dms` after JS
  edits.

- **2026-11-04 — A plugins dir created after startup is invisible.**
  `PluginService` watches `~/.config/dms/plugins/` with a `FolderListModel`.
  If the directory didn't exist when the shell started, a later `mkdir` or
  stow is never noticed: `dms ipc call plugins list` says "No plugins
  available". Run `systemctl --user restart dms` once, then
  `plugins enable <id>`.
- **2026-11-04 — The shell's QML is extracted at runtime.** The package has
  no `share/` QML tree. `dms run` unpacks it under
  `/run/user/1000/dms-shell/<hash>/` and runs `quickshell -p` on that path.
  That directory is the source to read when working out what Dux does,
  including `PLUGINS/README.md` and the example plugins.
- **2026-11-04 — An `Item` daemon logs one harmless warning.** A plugin
  daemon that is a bare `Item` (ours, for `IpcHandler`) logs "Created
  graphical object was not placed in the graphics scene" when it loads.
  It's harmless.

- **2026-11-03 — PAM fix carries over without config.** Dux's default
  ("Auto") lock auth on NixOS does not touch `/etc/pam.d`; it resolves the first
  existing login-like service (`login`), filters it, and writes a copy to
  `~/.local/state/dms/pam/`. Because nebula's `/etc/pam.d/login` already uses
  bare linux-pam module names (desktop-shell.nix), the copy inherits the
  glibc-bump fix. Source: `core/internal/pam/pam.go`.
- **2026-11-03 — Apps survive shell restarts.** Dux launches apps through
  `systemd-run --user --scope`, so restarting `dms.service` (including on a
  rebuild that changes it) does not kill them. Source: `quickshell/Common/LaunchUnit.js`.
- **2026-11-03 — Hyprland 0.57 `hyprctl binds` shows Lua binds as opaque ids**
  (`dispatcher: HL.Dispatcher(exec_cmd)`, `arg: "<n>"`), so a bind's command
  can't be read back from IPC — verify by key/modmask only.
- **2026-11-03 — `pkill -x noctalia` never matches.** The running process's
  `comm` is the wrapper's truncated name, `.noctalia-wrapp`, so an exact-name
  match misses; the old `autostart.lua` line (`pkill -x noctalia; …`) was a
  silent no-op. Use `pkill noctalia` (substring), or kill by PID from
  `pgrep -a noctalia`. Same for any nix-wrapped binary (`.dms-wrapped`,
  `.quickshell-wra…`).
- **2026-11-03 — `dms doctor` needs the session environment.** Run from a
  shell without `WAYLAND_DISPLAY` / `XDG_SESSION_TYPE` (e.g. an agent's
  subprocess), it reports "Display Server: Unknown" and every Quickshell
  feature (Polkit, IdleMonitor, BackgroundBlur…) as "Not available". Import
  the unit's env first: `eval "$(tr '\0' '\n' < /proc/$(systemctl --user show
  -p MainPID --value dms)/environ | grep -E '^(WAYLAND_DISPLAY|XDG_SESSION_TYPE)=' | sed 's/^/export /')"`.
- **2026-11-04 — "Can't paste a screenshot into Claude" was herdr, not Dux.**
  `dms screenshot` does put the image on the clipboard. It offers `image/png`,
  `text/plain` (the saved file's path), `text/uri-list` and
  `x-special/gnome-copied-files`. Claude Code's Ctrl+V runs `wl-paste`, and
  herdr panes had no `WAYLAND_DISPLAY` because hc's lingering core started
  before Hyprland. zsh's `session-env.zsh` now fixes new commands
  ([decision](../knowledge/decisions/herdr-pane-session-env.md)). A Claude
  that is already running must be restarted. Check from a pane with
  `wl-paste -l`: it should list `image/png`.
- **2026-11-03 — First-run log noise is expected.** Missing
  `settings.json`/`session.json`/cache files (created on first save), GeoClue2
  "not activatable" (weather falls back; no geoclue on nebula), Tailscale
  socket absent, `WorkspaceSwitcher.qml` binding-loop warnings. One to weigh:
  "Failed to initialize evdev manager … add your user to the 'input' group" —
  left as is: `input` lets any of k's processes read every keystroke, which
  isn't worth what Dux uses evdev for (a Caps Lock state indicator,
  `core/internal/server/evdev`).
