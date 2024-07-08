{
  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "tilingshell@ferrarodomenico.com"
      ];
    };
    "org/gnome/shell/extensions/tilingshell" = {
        last-version-name-installed = "11";
        enable-blur-snap-assistant = true;
        inner-gaps = 6;
        outer-gaps = 4;
        layouts-json = builtins.readFile ./tilingshell-layout.json;
        move-window-down = ["<Control><Super>j"];
        move-window-left = ["<Control><Super>h"];
        move-window-right = ["<Control><Super>l"];
        move-window-up = ["<Control><Super>k"];
        overridden-settings = builtins.readFile ./tilingshell-overrides.json;
        selected-layouts = ["Layout 5"];
      };
  };
}
