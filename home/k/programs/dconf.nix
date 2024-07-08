{ pkgs, ... }:
{
  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      command = "${pkgs.lib.getExe pkgs.kitty}";
      name = "Kitty";
      binding = "<Super>Return";
    };
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "tilingshell@ferrarodomenico.com"
      ];
    };
  };
  home.packages = with pkgs.gnome; [ dconf-editor ];
}
