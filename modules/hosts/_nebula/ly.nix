{
  # ly (the TUI login greeter) is enabled by snowglobe-lib's niri desktop
  # module (services.displayManager.ly.enable). Its config.ini is built from
  # `defaultConfig // services.displayManager.ly.settings`, so anything set
  # here overrides ly's defaults.
  #
  # ly ships with brightness controls bound to F5 (decrease) / F6 (increase),
  # which it advertises in the function-key hint bar at the bottom of the login
  # screen. Per ly's own config.ini, setting a *_key to the literal `null`
  # disables that action and removes its hint. This is narrower than
  # `hide_key_hints`, which would also drop the shutdown/reboot/toggle-password
  # hints. This is a desktop machine — no panel backlight to manage anyway.
  services.displayManager.ly.settings = {
    brightness_down_key = "null";
    brightness_up_key = "null";
  };
}
