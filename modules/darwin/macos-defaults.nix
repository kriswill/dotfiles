{
  flake.modules.darwin.macos-defaults =
    { lib, ... }:
    {
      system.defaults.NSGlobalDomain = {
        # Disable "natural" scrolling (reverse scroll direction to traditional)
        "com.apple.swipescrolldirection" = lib.mkDefault false;
        # Enable Ctrl+Cmd+click anywhere to drag windows (like Linux)
        NSWindowShouldDragOnGesture = lib.mkDefault true;
      };
      system.defaults.dock.autohide = lib.mkDefault true;
      # Tapping fn/🌐 alone does nothing (emoji picker stays on fn+e / ctrl+cmd+space)
      system.defaults.hitoolbox.AppleFnUsageType = lib.mkDefault "Do Nothing";
    };
}
