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
# not a "#!" script) — unless `programs.helium-chrome-shim.purgeGoogleChrome`
# is on.
#
# purgeGoogleChrome (host-selective, off by default): Google's system-scope
# updater (Omaha 4 "GoogleUpdater" + legacy Keystone, launchd-woken hourly as
# root) keeps a ticket for com.google.Chrome in /Library/Google/…/TicketStore
# long after Chrome.app is deleted. A ticket whose xcpath exists again — i.e.
# this shim's version-less fake .app — reads as "Chrome 0.0.0.0, needs
# updating", and the updater reinstalls a REAL Chrome over the shim (observed
# 2026-08-27 on k, then kept updating it; see docs/helium.md). Turning the
# option on boots out and deletes the updater daemons/agents, their install
# dirs and ticket stores, and any real Google Chrome.app, on every rebuild,
# so the shim can't be resurrected into the thing it replaces. The user's
# Chrome profile under ~/Library/Application Support/Google/Chrome is NOT
# touched (user data; delete by hand if wanted). Google Drive for desktop
# (DriveFS) also rides Keystone — don't enable this on a host that uses it.
{
  flake.modules.darwin.helium-chrome-shim =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      cfg = config.programs.helium-chrome-shim;
      shim = pkgs.writeText "google-chrome-helium-shim" ''
        #!/bin/sh
        # Shim so Chrome-only tooling launches Helium (see
        # modules/darwin/helium-chrome-shim.nix — managed by nix-darwin, do
        # not edit in place).
        exec "/Applications/Helium.app/Contents/MacOS/Helium" "$@"
      '';
      purge = ''
        # --- purgeGoogleChrome: evict Google's updater + any real Chrome ---
        console_uid="$(/usr/bin/stat -f %u /dev/console 2>/dev/null || echo 501)"
        for label in com.google.GoogleUpdater.wake.system com.google.keystone.daemon; do
          if [ -e "/Library/LaunchDaemons/$label.plist" ]; then
            /bin/launchctl bootout "system/$label" 2>/dev/null || true
            rm -f "/Library/LaunchDaemons/$label.plist"
            echo "helium-chrome-shim: removed launchd daemon $label"
          fi
        done
        for label in com.google.keystone.agent com.google.keystone.xpcservice; do
          if [ -e "/Library/LaunchAgents/$label.plist" ]; then
            /bin/launchctl bootout "gui/$console_uid/$label" 2>/dev/null || true
            rm -f "/Library/LaunchAgents/$label.plist"
            echo "helium-chrome-shim: removed launchd agent $label"
          fi
        done
        /usr/bin/pkill -f "GoogleUpdater.app/Contents/MacOS/GoogleUpdater" 2>/dev/null || true
        /usr/bin/pkill -f "GoogleSoftwareUpdate.bundle" 2>/dev/null || true
        for p in \
          "/Library/Application Support/Google/GoogleUpdater" \
          "/Library/Google/GoogleSoftwareUpdate" \
          "/Library/Google/Chrome" \
          "/Library/Google/Google Chrome Brand.plist" \
          "/Library/Caches/com.google.Keystone" \
          "/Library/Caches/com.google.GoogleUpdater"; do
          if [ -e "$p" ]; then
            rm -rf "$p"
            echo "helium-chrome-shim: removed $p"
          fi
        done
        if [ -f "$bin" ] && [ "$(head -c 2 "$bin")" != "#!" ]; then
          rm -rf "$app"
          echo "helium-chrome-shim: removed real Google Chrome.app (purgeGoogleChrome)"
        fi
      '';
    in
    {
      options.programs.helium-chrome-shim.purgeGoogleChrome = lib.mkEnableOption ''
        removing Google Chrome and Google's system updater (GoogleUpdater /
        Keystone) on every rebuild, so the Chrome shim is never "updated" back
        into a real Chrome. Leaves the user's Chrome profile alone. Do not
        enable where Google Drive for desktop is in use (it shares Keystone)
      '';

      # Order 1700: independent of dotfiles-stow (1500) / tmux (1600); just
      # keeps a stable slot. Runs as root; a root-owned shim is fine (nothing
      # checks ownership) and can't be clobbered by unprivileged processes.
      config.system.activationScripts.postActivation.text = lib.mkOrder 1700 ''
        app="/Applications/Google Chrome.app"
        bin="$app/Contents/MacOS/Google Chrome"
        helium="/Applications/Helium.app/Contents/MacOS/Helium"
        ${lib.optionalString cfg.purgeGoogleChrome purge}
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
