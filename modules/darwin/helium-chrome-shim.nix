# Chrome shim for Helium — Chrome-only tooling (chrome-devtools-mcp/Puppeteer)
# probes the canonical "/Applications/Google Chrome.app/…/Google Chrome" path
# for channel 'stable' with an existence-only check (accessSync), so a wrapper
# planted there makes it launch Helium instead — no per-tool --executablePath
# wiring. The wrapper exec's Helium's REAL binary by its real path, so Chromium
# resolves its own framework/helpers, args and the CDP pipe (fds 3/4) pass
# straight through, and close semantics are identical (exec keeps the PID, so
# puppeteer's browser.close() reaps Helium). Verified 2026-07-10: headful +
# headless + isolated + persistent-profile launches, SIGTERM/stdin-EOF close,
# and --browserUrl attach all work through the shim.
#
# Universal but self-guarding: no-op where Helium.app isn't installed (stale
# shims are removed), and it refuses to touch a real Google Chrome (a Mach-O,
# not a "#!" script).
{
  flake.modules.darwin.helium-chrome-shim =
    { lib, pkgs, ... }:
    let
      shim = pkgs.writeText "google-chrome-helium-shim" ''
        #!/bin/sh
        # Shim so Chrome-only tooling launches Helium (see
        # modules/darwin/helium-chrome-shim.nix — managed by nix-darwin, do
        # not edit in place).
        exec "/Applications/Helium.app/Contents/MacOS/Helium" "$@"
      '';
    in
    {
      # Order 1700: independent of dotfiles-stow (1500) / tmux (1600); just
      # keeps a stable slot. Runs as root; a root-owned shim is fine (nothing
      # checks ownership) and can't be clobbered by unprivileged processes.
      system.activationScripts.postActivation.text = lib.mkOrder 1700 ''
        app="/Applications/Google Chrome.app"
        bin="$app/Contents/MacOS/Google Chrome"
        helium="/Applications/Helium.app/Contents/MacOS/Helium"
        if [ ! -x "$helium" ]; then
          # No Helium here — drop a stale shim (never a real Chrome binary).
          if [ -f "$bin" ] && [ "$(head -c 2 "$bin")" = "#!" ]; then
            rm -rf "$app"
            echo "helium-chrome-shim: Helium.app missing; removed stale shim"
          fi
        elif [ -f "$bin" ] && [ "$(head -c 2 "$bin")" != "#!" ]; then
          echo "helium-chrome-shim: real Google Chrome.app present; leaving it alone"
        else
          mkdir -p "$app/Contents/MacOS"
          install -m 0755 ${shim} "$bin"
        fi
      '';
    };
}
