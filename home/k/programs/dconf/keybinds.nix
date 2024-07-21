{ pkgs, ... }: {
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" =
      {
        command = "${pkgs.lib.getExe pkgs.kitty}";
        name = "Kitty";
        binding = "<Super>Return";
      };
  };
}
