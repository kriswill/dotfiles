# fastfetch manual (nebula)

A working reference for **fastfetch** as configured on `nebula` (ghostty under
Hyprland, usually inside tmux). Distilled from the upstream wiki and **verified
against the binary and live rendering on this machine** (screenshots of real
ghostty+tmux panes). Maintained for Claude's use: keep it accurate, prune what
stops being true, and record real gotchas in **Learned behaviours & workarounds**
at the bottom.

## Version & state on nebula (read this first)

```
$ fastfetch --version
fastfetch 2.64.2 (x86_64)
$ kitten --version
kitten 0.47.4 created by Kovid Goyal
$ command -v fastfetch kitten kitty
/run/current-system/sw/bin/fastfetch
/run/current-system/sw/bin/kitten        # required by logo type "kitty-icat"
/run/current-system/sw/bin/kitty
```

- **Install:** comes from snowglobe-lib's package set (it's on the system
  `PATH`, not declared in this repo). `kitten`/`kitty` are also already on
  `PATH` here — unlike the macOS/`main` branch, which needed a custom `kitten`
  derivation because kitty.app's `kitten` wasn't standalone.
- **Config:** `home/fastfetch/.config/fastfetch/config.jsonc`, a **stowed**
  dotfile (symlinked into `~/.config/fastfetch/` by `dotfiles-stow.nix`, not
  nix-managed). The logo image lives next to it as `Nebula.png` and is
  referenced by `~/.config/fastfetch/Nebula.png`. Swap the file to change the
  logo. (`logo.png` is an older leftover.)

## The logo image situation on nebula (the load-bearing facts)

**Terminal here is ghostty 1.3.1, not kitty.** ghostty speaks the kitty graphics
protocol but is *not* the kitty terminal — this is why the macOS recipe doesn't
transplant unchanged. Two independent things have to be true for the PNG to
render inside tmux:

1. **`logo.type` must be `"kitty-icat"`.** It is the *only* image protocol that
   renders in ghostty+tmux here. Verified by screenshotting every variant in a
   real pane:

   | `logo.type` | ghostty direct | ghostty + tmux | why |
   |---|---|---|---|
   | `kitty` (native) | ✗ malformed | ✗ | fastfetch emits a payload **2× the declared size** → ghostty logs `unexpected length … expected_len=594000 actual_len=1188000` / `erroneous kitty graphics response: EINVAL` and draws nothing |
   | `kitty-direct` | ✓ | ✗ (ASCII) | terminal reads the file itself; falls back to builtin ASCII under tmux |
   | `sixel` | — | ✗ (ASCII) | falls back to builtin ASCII under tmux |
   | `kitty-icat` | ✓ | **✓** | shells out to `kitten icat`, which handles tmux passthrough correctly |

2. **tmux's `TERM` must NOT be the literal string `"screen"`.** This is the part
   that actually broke nebula. See next section.

`kitty-icat` shells out to `kitten icat`; pros = works in tmux + gif animations +
good performance; con = it **clears the screen** before drawing (a `kitten icat`
limitation). The `kitten` binary must be on `PATH` (it is here).

## Why it silently fell back to ASCII inside tmux (the bug we fixed)

fastfetch hard-blocks **every** image logo type when `TERM` is *exactly*
`"screen"`. From `src/logo/image/image.c` (2.64.2):

```c
const char* term = getenv("TERM");
if ((term && ffStrEquals(term, "screen")) || getenv("ZELLIJ")) {
    if (printError)
        fputs("Logo: Image logo is not supported in terminal multiplexers\n", stderr);
    return false;   // → falls back to builtin ASCII
}
```

tmux on nebula had **no `default-terminal`** set, so it defaulted to bare
`screen` → `TERM=screen` inside every pane → the guard tripped → builtin NixOS
ASCII snowflake instead of the PNG, **silently** (the error only prints with
`--show-errors`). It works on macOS because that tmux uses a non-`screen` TERM.

**The check is an exact string compare.** Anything else — `tmux-256color`,
`screen-256color`, `xterm-ghostty` — passes. Fix lives in
[`tmux.md`](tmux.md): `set -g default-terminal "tmux-256color"`. After that,
`logo.type: "kitty-icat"` renders in ghostty+tmux. (Both changes are required;
either one alone still shows ASCII.)

> Diagnostic reflex: if the logo is ASCII when you expect the image, run
> `fastfetch --show-errors` in the real pane. `Image logo is not supported in
> terminal multiplexers` = the `TERM=="screen"` guard. `Image logo is not
> supported in pipe mode` = stdout is redirected/not a tty (e.g. you piped it).

## Config options (official `logo` object)

`config.jsonc` → top-level `"logo": { … }`. Keys verified against the upstream
wiki (2.64.2):

| Key | Meaning | Default |
|---|---|---|
| `type` | logo type enum (below) | `"auto"` |
| `source` | file path / builtin name / data | `""` |
| `width` | image width **in characters** (aspect-preserved if `height` unset) | — |
| `height` | image height **in characters** | — |
| `padding` | shorthand for left+right padding | — |
| `paddingTop` | rows above the logo | `0` |
| `paddingLeft` | columns left of the logo | `0` |
| `paddingRight` | columns between logo and info block | `4` |
| `color1`…`color9` | override builtin-ASCII colors | `""` |
| `preserveAspectRatio` | iTerm protocol only | `false` |
| `recache` | refresh cached logo data | — |
| `separate` | render logo on its own line, info below | — |
| `printRemaining` | print info lines that overflow past the logo | `true` |

**`type` enum:** `auto`, `builtin`, `small`, `file`, `file-raw`, `data`,
`data-raw`, `sixel`, `kitty`, `kitty-direct`, `kitty-icat`, `iterm`, `chafa`,
`raw`, `none`. CLI shortcuts exist for the image ones (`--kitty-icat <path>` ==
`--logo-type kitty-icat --logo <path>`).

Remarks that matter here:
- `kitty-direct` and `iterm` **require** both `width` and `height`.
- `kitty-icat` sizes via `kitten icat`; our config sets `width: 27, height: 20`
  (characters) to match the info block height.
- Image protocols (`sixel`/`kitty`/`iterm`/`chafa`) need fastfetch built with
  ImageMagick — `kitty-icat` sidesteps that by delegating to `kitten`.

## Current nebula config (the working state)

```jsonc
"logo": {
  "type": "kitty-icat",
  "source": "~/.config/fastfetch/Nebula.png",
  "width": 27,
  "height": 20
}
```

## How these facts were tested (ghostty + Hyprland + grim harness)

There is no controlling tty in the agent's shell, so `kitten icat`/fastfetch
image rendering can't be reproduced by running them directly — they error with
`open /dev/tty: no such device or address` or fall to "pipe mode". The image
*does* render in a real on-screen ghostty pane, so the reliable method is to
**launch a real ghostty window, run the command in it, and screenshot the
compositor.** Recipe (Hyprland, Wayland output `wayland-1`):

```sh
export HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr | head -1)

# 1. Launch ghostty detached, running the test, holding open with sleep.
#    Use setsid + disown so it survives the tool call; a unique --title makes
#    it findable. Wrap in tmux for the in-tmux case.
setsid zsh -lc 'WAYLAND_DISPLAY=wayland-1 ghostty --title=TEST -e zsh -lc \
  "cd ~/.config/fastfetch; fastfetch --show-errors --logo-type kitty-icat \
   --logo ~/.config/fastfetch/Nebula.png; echo READY; sleep 600"' & disown

# 2. Find the window's pixel geometry by its title (scale is 1.0 here, so
#    compositor logical coords == grim pixel coords).
hyprctl clients -j | jq -r '.[]|select(.title=="TEST")|"\(.size[0])x\(.size[1])+\(.at[0])+\(.at[1])"'
# e.g. 1691x1362+1462+1022

# 3. Screenshot the whole layout, crop to the window, downscale to read it.
WAYLAND_DISPLAY=wayland-1 grim /tmp/shot.png
magick /tmp/shot.png -crop 1691x1362+1462+1022 +repage -resize 900x /tmp/win.png
# then Read /tmp/win.png
```

Hard-won gotchas from doing this (so the next session doesn't relearn them):

- **`grim` captures all outputs into one image** (here `4880x3440` across two
  3440x1440 monitors at `+0,0` and `+1440,1000`). Crop by the window geometry
  from `hyprctl`, don't eyeball.
- **Match the window by a unique `--title`, not by `pid` or a title substring.**
  This Claude session's own ghostty window had `fastfetch` in its title and kept
  getting matched/cropped by mistake. All ghostty share `class
  com.mitchellh.ghostty`; the editor/Claude window here is pid `2853` — exclude
  it when bulk-killing test windows.
- **The window must be wide enough** or fastfetch drops the image and prints the
  big builtin ASCII logo — a too-narrow tiled pane (e.g. 411px) reads as a false
  "fallback". Float+enlarge or just let it tile full-width.
- **`default-terminal` only applies at pane creation**, so testing the tmux fix
  needs a *fresh* tmux server with the setting already loaded — don't `tmux set`
  it into a running pane and expect `TERM` to change. Use a private socket and an
  explicit config so you don't disturb the user's live server:
  `tmux -L test -f /tmp/test.conf new-session "…"`, and
  `tmux -L test kill-server` to clean up.
- **Don't redirect fastfetch's stdout to capture errors** — it then thinks it's
  piped and refuses the image for an unrelated reason ("pipe mode"). Run on the
  tty with `--show-errors` and read the error off the screenshot instead.
- **Avoid `pkill -f` to clean up test windows** — it matched and killed the
  agent's own command chain (exit 144). Kill by explicit pid from `hyprctl
  clients -j` instead.

## Learned behaviours & workarounds

- **ASCII instead of the PNG inside tmux = `TERM=="screen"` guard**, not a
  terminal/passthrough problem. Proof: raw `kitten icat ~/.config/fastfetch/Nebula.png`
  renders perfectly in the same ghostty+tmux pane. Fix is the tmux
  `default-terminal`, not anything in fastfetch. (2026-06-20)
- **Use `kitty-icat`, never native `kitty`, with ghostty.** Native `kitty`
  ships a payload exactly 2× the declared length and ghostty rejects it
  (`EINVAL`). `kitty-direct`/`sixel` work bare but fall back to ASCII under tmux.
  (2026-06-20)
- **`KITTY_WINDOW_ID=1` does NOT bypass the guard** — tried it; the gate is purely
  `TERM=="screen" || $ZELLIJ`, it does not consult terminal-identity env vars.
  Only changing `TERM` works. (2026-06-20)
- **ghostty leaks `GHOSTTY_RESOURCES_DIR`/`GHOSTTY_BIN_DIR` through tmux** (they
  survive into the pane), but fastfetch's image guard ignores them. Inside tmux
  fastfetch reports `Terminal: tmux 3.6a`; outside it reports `Terminal: ghostty
  1.3.1`. Not actionable for the logo, but explains the "Terminal" line flipping.
  (2026-06-20)

## Sources

- [fastfetch — Logo options wiki](https://github.com/fastfetch-cli/fastfetch/wiki/Logo-options)
- [fastfetch `src/logo/image/image.c` @ 2.64.2](https://github.com/fastfetch-cli/fastfetch/blob/2.64.2/src/logo/image/image.c) — the `TERM=="screen"` guard
- [fastfetch #861 — Don't disable image logos inside tmux](https://github.com/fastfetch-cli/fastfetch/issues/861)
- [Discussion #1039 — use kitten icat for logo](https://github.com/fastfetch-cli/fastfetch/discussions/1039)
- Machine-verified on nebula via screenshots of real ghostty+tmux panes (grim + `magick` crop), `fastfetch --show-errors`, `fastfetch -s terminal`, and `env` diffs in/out of tmux, 2026-06-20.
