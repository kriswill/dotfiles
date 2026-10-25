{
  flake.modules.darwin.macos-defaults =
    { config, lib, ... }:
    let
      user = config.system.primaryUser;
      # The Dock's preferences, read the way nix-darwin writes user defaults:
      # as the user, inside their launchd session (so cfprefsd answers).
      dockPrefs = "/bin/launchctl asuser \"$(/usr/bin/id -u ${user})\" /usr/bin/sudo --user=${user} -- /usr/bin/defaults export com.apple.dock -";
    in
    {
      system.defaults.NSGlobalDomain = {
        # Disable "natural" scrolling (reverse scroll direction to traditional)
        "com.apple.swipescrolldirection" = lib.mkDefault false;
        # Enable Ctrl+Cmd+click anywhere to drag windows (like Linux)
        NSWindowShouldDragOnGesture = lib.mkDefault true;
      };
      # Dock settings go through CustomUserPreferences, NOT system.defaults.dock:
      # nix-darwin kills the Dock on EVERY activation whenever any
      # system.defaults.dock option is set (defaults-write.nix: `length dock >
      # 0`), a visible blink on each switch even when nothing changed.
      # CustomUserPreferences writes the same com.apple.dock keys without that,
      # and the Dock is restarted below only when activation actually changed
      # its preferences. (Setting any system.defaults.dock option anywhere
      # brings the unconditional restart back.)
      system.defaults.CustomUserPreferences."com.apple.dock".autohide = lib.mkDefault true;
      system.activationScripts.preActivation.text = ''
        dockPrefsBefore="$(${dockPrefs} 2>/dev/null || true)"
      '';
      system.activationScripts.postActivation.text = ''
        if [ "$(${dockPrefs} 2>/dev/null || true)" != "''${dockPrefsBefore-}" ]; then
          echo >&2 "restarting Dock..."
          /usr/bin/killall -qu ${user} Dock || true
        fi
      '';
      # Tapping fn/🌐 alone does nothing (emoji picker stays on fn+e / ctrl+cmd+space)
      system.defaults.hitoolbox.AppleFnUsageType = lib.mkDefault "Do Nothing";
    };
}
