{ pkgs, ... }: {
  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      command = "${pkgs.kitty}/bin/kitty";
      name = "Kitty";
      binding = "<Super>Return";
    };
  };
  home.packages = with pkgs.gnome; [
    dconf-editor
  ];
}