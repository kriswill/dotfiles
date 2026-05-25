# Testing Neovim configuration with Neovide

How to drive a real Neovide GUI session to verify config changes that depend on
visible UI rendering — completion menus, popups, statuscolumn glyphs, theme
colors, etc. Headless `nvim --headless` covers logic, but it can't tell you
whether a popup actually paints.

## When to use this

- Verifying a completion plugin renders (blink.cmp, nvim-cmp, native pum).
- Confirming UI plugins paint correctly (lualine, snacks dashboard, noice,
  which-key popups).
- Smoke-testing a config change end-to-end before committing.
- Reproducing a "looks weird" bug a screenshot from headless can't capture.

For pure-logic checks (LSP attaches, autocmds fire, options resolve), use
`nvim --headless -c '<lua>' -c 'qa!'` instead — it's faster.

## How Neovide reaches your wrapped nvim

Neovide is the GUI driver. It spawns home-manager's wrapped `nvim` —
`NEOVIDE_NEOVIM_BIN` is set in `modules/home-manager/neovide/default.nix`
to `lib.getExe config.programs.neovim.finalPackage` — so what you see is
exactly the config you're editing, with every `programs.neovim.extraPackages`
entry (LSP servers, formatters) on `PATH`.

The Neovide bundle lives at `~/Applications/Home Manager Apps/Neovide.app`,
materialised as a real `.app` directory by home-manager's
`targets.darwin.copyApps` (default-on at `home.stateVersion = "26.05"`, set
in `lib/default.nix`). That detail matters because real bundle directories
are what GUI-automation tools enumerate — Finder-alias stubs are not.

## Driving Neovide via the computer-use MCP (preferred)

Inside a Claude Code session with the computer-use MCP available, drive
Neovide through MCP tools. Real bundle directories under
`~/Applications/Home Manager Apps/` are enumerated by the MCP scanner, so
Neovide is grantable at tier `"full"` — no restrictions on typing, key
presses, clicks, or screenshots.

Recipe:

1. **Grant access** — once per session:

   ```text
   mcp__computer-use__request_access(applications: ["Neovide"])
   ```

   Expect `granted` with `bundleId: "com.neovide.neovide"` and tier
   `"full"`. If it returns `not_installed`, the bundle is missing — run
   `darwin-rebuild switch --flake .` and try again.

2. **Open the buffer**:

   ```text
   mcp__computer-use__open_application(
     name: "Neovide",
     path: "/Users/k/src/dotfiles/config/nvim/init.lua"
   )
   ```

   This brings the window forward, so subsequent keystrokes and
   screenshots target it.

3. **Drive it** with `mcp__computer-use__type`,
   `mcp__computer-use__key`, and `mcp__computer-use__left_click`. Tier
   `"full"` means no input restrictions.

4. **Wait, then capture.** Neovide renders asynchronously and blink.cmp's
   `auto_show` debounces, so insert
   `mcp__computer-use__wait(ms: 700)` before
   `mcp__computer-use__screenshot` after any popup trigger. Without the
   wait, the popup may not have painted yet.

`mcp__computer-use__computer_batch` lets you submit a sequence
(open → type → wait → screenshot) in one call, which is the typical shape
for a smoke test.

## Fallback: shell-only driving via osascript + screencapture

When you are outside an MCP-equipped Claude session — a CI smoke-test
script, a one-off invocation from a plain Terminal, or debugging the MCP
path itself — drive Neovide directly via macOS automation.

```sh
# 1. Kill any stale Neovide session so env vars are fresh.
pkill -f neovide || true

# 2. Launch on a real buffer.
open -a Neovide /Users/k/src/dotfiles/config/nvim/init.lua

# 3. Bring it forward (otherwise screencapture grabs whatever's on top).
osascript -e 'tell application "System Events" to set frontmost of \
  (first process whose bundle identifier is "com.neovide.neovide") to true'
```

Send keystrokes — note the process name is `.neovide-wrapped` (the nix
wrapper), not `Neovide`:

```sh
# Send :lua vim.<Tab> to trigger blink.cmp's cmdline source.
osascript -e 'tell application "System Events" to tell process \
  ".neovide-wrapped" to keystroke ":lua vim."'

# Special keys via key code: 53 = Escape, 36 = Return, 48 = Tab.
osascript -e 'tell application "System Events" to tell process \
  ".neovide-wrapped" to key code 53'
```

This requires Accessibility permission for whatever process is running
`osascript` (Terminal, the Claude Code CLI, etc.). macOS prompts on first
use and remembers the grant.

For deterministic timing, sleep between keystroke and screencapture —
the same render-async constraint as the MCP path:

```sh
osascript -e '... keystroke ":lua vim."'
sleep 0.7
screencapture -x /tmp/menu.png
```

`screencapture -x` is the macOS built-in. The `-x` flag suppresses the
shutter sound. Output is full-resolution PNG (4096×2304 on this Retina
display).

```sh
screencapture -x /tmp/full.png

# Crop to the Neovide window region (top-left ~2400×1400 covers it).
sips --cropToHeightWidth 1400 2400 --cropOffset 0 0 \
  /tmp/full.png --out /tmp/crop.png

# Resample down for easier viewing.
sips --resampleWidth 1600 /tmp/crop.png --out /tmp/crop_small.png
```

`sips` is built into macOS — no extra deps.

## Common pitfalls

- **Stale Neovide instance.** Old `nvim` keeps running with stale env vars
  and config. Always `pkill -f neovide` before retesting.
- **Frontmost wrong.** Screencapture and synthesized keystrokes both
  target whatever's in front — bring Neovide forward explicitly, don't
  assume. `open_application` handles this on the MCP path; the shell
  fallback does not.
- **Render timing.** Wait 0.5–1.0s between the last keystroke and the
  screenshot — `mcp__computer-use__wait(ms: 700)` on the MCP path,
  `sleep 0.7` in shell. blink.cmp's `auto_show` debounces; popups don't
  paint instantly.
- **Wrong process name (shell fallback only).** It's `.neovide-wrapped`,
  not `Neovide` or `neovide`. Check with
  `osascript -e 'tell app "System Events" to get name of every process'`.
  The MCP path doesn't need the process name.
- **Accessibility permission (shell fallback only).** The first
  `osascript ... keystroke` call from a new parent process triggers a
  system prompt. If keystrokes silently no-op, that's why — check System
  Settings → Privacy & Security → Accessibility. The MCP path uses its
  own `request_access` flow and doesn't share this gate.
- **`request_access` returns `not_installed`.** The
  `~/Applications/Home Manager Apps/Neovide.app` bundle is missing or
  stale. Re-run `darwin-rebuild switch --flake .`. If a previous attempt
  left bare `~/Applications/<App>.app` symlinks, the
  `cleanupLegacyAppBundleSymlinks` activation in
  `modules/home-manager/default.nix` removes them on the next switch
  (manifest-gated, runs once per host).
