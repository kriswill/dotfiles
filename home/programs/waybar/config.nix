{
  mainBar = {
    layer = "top"; # Waybar at top layer
    position = "bottom"; # Waybar position (top|bottom|left|right)
    height = 28; # Waybar height (to be removed for auto height)
    spacing = 6; # Gaps between modules (4px)
    modules-left = [ "hyprland/workspaces" ];
    modules-center = [ "hyprland/window" ];
    modules-right = [
      "idle_inhibitor"
      "pulseaudio"
      "network"
      "cpu"
      "memory"
      "temperature"
      # "backlight"
      # "battery"
      "clock"
      "tray"
    ];
    # Modules configuration
    "hyprland/workspaces" = {
      disable-scroll = true;
      # all-outputs = true;
      warp-on-scroll = false;
      on-click = "activate";
      urgent = "";
      active = "";
      # default = "";
      sort-by-number = true;
    };
    idle_inhibitor = {
      format = "{icon}";
      format-icons = {
        activated = "";
        deactivated = "";
      };
    };
    tray = {
      # "icon-size = 21;
      spacing = 5;
    };
    "clock#time" = {
      interval = 1;
      format = "{:%I:%M:%S %p}";
      timezone = "America/Los_Angeles";
      tooltip-format = ''
        <big>{:%Y %B}</big>
        <tt><small>{calendar}</small></tt>
      '';
    };
    # clock = {
    #   timezone = "America/Los_Angeles";
    #   tooltip-format = "<big>{:%F %a}</big>\n<tt><small>{calendar}</small></tt>";
    #   format-alt = "{:%Y-%m-%d}";
    # };
    cpu = {
      format = "{usage}% ";
      tooltip = false;
    };
    memory = {
      format = "{}% ";
    };
    temperature = {
      critical-threshold = 80;
      format = "{temperatureC}°C {icon}";
      format-icons = [
        ""
        ""
        ""
      ];
    };
    # backlight = {
    #   scroll-step = 5;
    #   format = "{percent}% {icon}";
    #   format-icons = [ "" "" "" "" "" "" "" "" "" ];
    # };
    # battery = {
    #   states = {
    #     warning = 30;
    #     critical = 15;
    #   };
    #   format = "{capacity}% {icon}";
    #   format-full = "{capacity}% {icon}";
    #   format-charging = "{capacity}% ";
    #   format-plugged = "{capacity}% ";
    #   format-alt = "{time} {icon}";
    #   format-icons = [ "" "" "" "" "" ];
    # };
    network = {
      format-wifi = "{essid} ({signalStrength}%) ";
      format-ethernet = "{ipaddr}/{cidr} ";
      tooltip-format = "{ifname} via {gwaddr} ";
      format-linked = "{ifname} (No IP) ";
      format-disconnected = "Disconnected ⚠";
      format-alt = "{ifname}: {ipaddr}/{cidr}";
    };
    pulseaudio = {
      scroll-step = 5;
      format = "{volume}% {icon} {format_source}";
      format-bluetooth = "{volume}% {icon} {format_source}";
      format-bluetooth-muted = " {icon} {format_source}";
      format-muted = " {format_source}";
      format-source = "{volume}% ";
      format-source-muted = "";
      format-icons = {
        headphone = "";
        hands-free = "";
        headset = "";
        phone = "";
        portable = "";
        car = "";
        default = [
          ""
          ""
          ""
        ];
      };
      on-click = "pavucontrol";
    };
  };
}
