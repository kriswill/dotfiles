{
  configurations.nixos.nebula.module = {
    # Battle.net in GE-Proton without Steam or umu (modules/nixos/battlenet.nix,
    # from ./flakes/battlenet): `battlenet` and a "Battle.net" desktop entry.
    # The prefix is the module's default, ~/.local/share/battlenet. It moved
    # there from Steam's compatdata/3082075026 on 2026-10-25, so Steam can't
    # touch it (see knowledge/modules/nebula-battlenet.md).
    programs.battlenet = {
      enable = true;
      icon = "/home/k/Downloads/wow-icon.png";
      # The Ryzen 9 9900X3D's 3D V-Cache CCD: cores 0-5 and their SMT
      # siblings share the 96 MB L3 (6-11,18-23 share 32 MB). WoW is
      # cache-hungry. amd_x3d_mode stays "frequency", so other work prefers
      # the other CCD and leaves these cores to the game.
      cpus = "0-5,12-17";
      # While a session runs, app.slice is held to the other CCD, 6-11,18-23.
      # It holds the terminals, Claude sessions, the sccache server that
      # spawns the compilers, and wowdps-dev. The game runs in battlenet.slice.
      # session.slice (Hyprland and what it starts directly) is left alone.
      confineSlices = [ "app.slice" ];
      environment = {
        # Wine's Wayland driver instead of XWayland: WoW ran a little faster
        # (2026-10-25). Battle.net's window lays out oddly for a few seconds
        # after it opens, then settles.
        PROTON_ENABLE_WAYLAND = "1";
        # Wine's primary monitor. Proton looks for xrandr's "primary" output,
        # and XWayland under Hyprland marks none, so Wine picked its own. DP-1
        # is portrait, and WoW sized its fullscreen window for the wrong
        # screen. DP-3 is the OLED that workspace 9 (WoW's, see
        # home/hyprland/.config/hypr/window-rules.lua) lives on.
        PROTON_WAYLAND_MONITOR = "DP-3";
      };
    };
  };
}
