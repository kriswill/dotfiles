{
  flake.modules.darwin.macos-defaults = {
    system.defaults.NSGlobalDomain = {
      # Disable "natural" scrolling (reverse scroll direction to traditional)
      "com.apple.swipescrolldirection" = false;
      # Enable Ctrl+Cmd+click anywhere to drag windows (like Linux)
      NSWindowShouldDragOnGesture = true;
    };
    system.defaults.dock.autohide = true;
  };
}
