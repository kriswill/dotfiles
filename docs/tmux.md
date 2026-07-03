# tmux manual (nebula)

A working reference for **tmux** as configured on `nebula` (ghostty under
Hyprland). Covers how the config is split between the stow tree and a Nix
module, the deliberate settings (and the non-obvious *why* behind them), and the
graphics/passthrough hacks that make image tools work inside tmux. Maintained for
Claude's use: keep it accurate, prune what stops being true, and record real
gotchas in **Learned behaviours & workarounds** at the bottom.

## Version & state on nebula (read this first)

```
$ tmux -V
tmux 3.6a
$ command -v tmux
/run/current-system/sw/bin/tmux
$ tmux show -gv default-terminal      # inside tmux
tmux-256color
$ echo $TERM                          # inside tmux
tmux-256color                          # NOT "screen" — load-bearing, see below
```

- **Prefix is `C-Space`** (not `C-b`). `prefix + C-Space` = last-window.
- tmux is **3.6a**, so all the `tmux_version < 3.0` legacy branches in the config
  are dead weight carried over from the cross-host config — harmless.

## How the config is managed (two pieces, two mechanisms)

nebula does **not** run home-manager, so the cross-host (`main`) home-manager
tmux module is ported to plain NixOS as a split:

1. **Static config — stowed.** `home/tmux/.config/tmux/tmux.conf` (and the
   tmux-which-key `config.yaml`) live in the stow tree and are symlinked into
   `~/.config/tmux/` by `dotfiles-stow.nix` — the **live editable repo copy**,
   not a `/nix/store` snapshot. Edit the file in the repo; changes are immediate
   (reload with `prefix + r`).
2. **`plugins.conf` — Nix-generated.** `tmux.conf` sources
   `~/.config/tmux/plugins.conf`, which must point at the tmux-which-key plugin's
   `/nix/store` runtime path (a value only Nix knows). That one file can't be a
   static stow symlink, so `modules/nixos/tmux.nix` writes it and drops it in via
   `systemd.tmpfiles` (`L+`, so it tracks rebuilds). The same module installs
   `pkgs.tmux` and owns `~/.config/tmux` as `k` so stow and tmpfiles don't race.

So: **tmux settings → edit `home/tmux/.config/tmux/tmux.conf`. Plugins/runtime
paths → edit `modules/nixos/tmux.nix` + rebuild.**

## Settings worth knowing (and the non-obvious why)

| Setting | Value | Why |
|---|---|---|
| `default-terminal` | `tmux-256color` | **Must not be the literal `"screen"`** — fastfetch (and other tools) hard-block image logos when `TERM=="screen"`. Also gives correct truecolor/italics terminfo. See the caveat section. |
| `allow-passthrough` | `all` | Lets DCS passthrough escapes (kitty graphics, etc.) reach the outer terminal — required for any in-pane image rendering. |
| `terminal-features` | `*:usstyle`, `,xterm-ghostty:clipboard` | Underline styles everywhere; OSC-52 clipboard for ghostty specifically. |
| `set-clipboard` | `on` | Programs can set the system clipboard via OSC-52. |
| `set-titles` + `set-titles-string` | `#S ▸ #W…` | Reports session/window/pane to the **outer terminal title**, so Hyprland window decorations / taskbars show what tmux is displaying. |
| `extended-keys` | `on`, `csi-u` | CSI-u key encoding so apps see `C-Space`, modified keys, etc. |
| `escape-time` | `0` | No ESC delay (vim responsiveness). |
| `base-index` / `renumber-windows` | `1` / `on` | 1-based windows, gap-free after closing one. |
| `mouse` | `on` | |

**vim-tmux-navigator:** `C-h/j/k/l` switch panes, but defer to Vim when the
active pane runs vim/nvim/view/fzf (the `is_vim` `ps`-based check at the top of
the config). `C-\` = last pane, `C-Space` = cycle.

**Plugin:** tmux-which-key (XDG-enabled) — discoverable keybind menu, loaded via
the Nix-generated `plugins.conf`.

## Graphics / images inside tmux (the caveat that bit us)

Images (kitty graphics protocol, sixel) only work in a pane when **both** of
these hold:

1. **`set -g allow-passthrough all`** (present) — forwards the graphics escapes.
2. **`TERM` inside tmux is not the literal `"screen"`** — i.e.
   `default-terminal "tmux-256color"` (present). Some tools refuse images
   entirely when they see `TERM=screen`. The headline case is **fastfetch**,
   which falls back to its ASCII logo *silently*; full diagnosis and fix in
   [`fastfetch.md`](fastfetch.md).

Raw `kitten icat <png>` renders fine in a ghostty+tmux pane once those two are
set — proof the passthrough plumbing is correct. If an image tool still won't
render, the problem is almost always that tool's own `TERM`/multiplexer
detection, not tmux.

## How tmux/graphics changes were tested here

Testing in-pane rendering needs a **real on-screen ghostty window** (the agent's
shell has no controlling tty, so `kitten icat`/fastfetch error with `/dev/tty`
or "pipe mode" when run directly). The full grim-screenshot harness — launch a
detached ghostty by unique `--title`, find its geometry with `hyprctl clients
-j`, `grim` the output, `magick -crop` to the window — is documented once in
[`fastfetch.md`](fastfetch.md#how-these-facts-were-tested-ghostty--hyprland--grim-harness).

tmux-specific testing notes:

- **`default-terminal` only applies at pane creation.** `tmux set
  default-terminal …` in a running pane does **not** change that pane's `TERM`.
  To test the setting, start a *fresh* server with it already in the config.
- **Don't disturb the user's live tmux server.** Use a private socket and an
  explicit config: `tmux -L test -f /tmp/test.conf new-session "…"`, then
  `tmux -L test kill-server` to clean up. `-f /dev/null` gives a vanilla server
  with zero config when you want a clean baseline.
- After editing the live config, the user's **running server keeps its old
  `TERM`** — they must `tmux kill-server` (or exit all sessions) for
  `default-terminal` to take effect in new panes.

## Learned behaviours & workarounds

- **`default-terminal` was unset → defaulted to bare `screen` → `TERM=screen`**,
  which made fastfetch (and any tool with the same guard) refuse image logos.
  Setting `tmux-256color` fixed it. The check elsewhere is often an *exact*
  string compare on `"screen"`, so `tmux-256color`/`screen-256color` both pass.
  (2026-06-20)
- **`tmux set default-terminal` mid-session is a no-op for the current pane.**
  Burned time testing the fix this way before realizing `TERM` is fixed at pane
  creation. Always test with a fresh server. (2026-06-20)
- **ghostty env (`GHOSTTY_RESOURCES_DIR`, `GHOSTTY_BIN_DIR`, …) survives into
  tmux panes**, but `TERM_PROGRAM` is overwritten to `tmux` and `TERM` to
  whatever `default-terminal` is. Tools that key off `TERM_PROGRAM` will see
  `tmux`, not `ghostty`. (2026-06-20)

## Sources

- [tmux(1) manual](https://man.openbsd.org/tmux.1) — `default-terminal`,
  `allow-passthrough`, `terminal-features`, `set-titles`.
- [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) — the
  `is_vim` pane-switching integration.
- Sibling manual [`fastfetch.md`](fastfetch.md) — the `TERM=="screen"` image
  guard and the grim/ghostty test harness.
- Repo: `home/tmux/.config/tmux/tmux.conf` (stowed), `modules/nixos/tmux.nix`
  (plugins.conf generation + install), `modules/nixos/dotfiles-stow.nix`.
- Machine-verified on nebula, 2026-06-20: `tmux -V`, `tmux show -gv
  default-terminal`, `echo $TERM` in/out of tmux, `infocmp tmux-256color`.
