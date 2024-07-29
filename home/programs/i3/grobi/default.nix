{ pkgs, ... }:

{
  services.grobi = {
    enable = true;
    rules = [
      {
        name = "main";
        atomic = true;
        outputs_connected = [ "DP-0" "DP-2" ];
        configure_single = "DP-2";
        primary = true;
      }
      {
        name = "left-screen";
        outputs_connected = [ "DP-0" "DP-2" ];
        configure_single = "DP-0";
        primary = true;
        atomic = true;
        execute_after = [
          "${pkgs.unstable.xorg.xrandr}/bin/xrandr --output DP-0 --rotate left"
        ];
      }
    ];
  };
}
