{ config, lib, options, pkgs, ... }:
let
  inherit (lib) mkIf mkMerge;
  inherit (lib.internal) mkBoolOpt enabled;

  cfg = config.k.apps.firefox;
in
{
  options.k.apps.firefox =
    {
      enable = mkBoolOpt false "Whether or not to enable Firefox.";
    };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.floorp
    ];

    services.gnome.gnome-browser-connector.enable = config.k.desktop.gnome.enable;

    k.home = {
      file = mkMerge [
        (mkIf config.k.desktop.gnome.enable {
          ".mozilla/native-messaging-hosts/org.gnome.chrome_gnome_shell.json".source = "${pkgs.chrome-gnome-shell}/lib/mozilla/native-messaging-hosts/org.gnome.chrome_gnome_shell.json";
        })
      ];
    };

    programs.firefox = enabled;
  };
}
