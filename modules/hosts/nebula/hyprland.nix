{
  configurations.nixos.nebula.module =
    { pkgs, inputs, ... }:
    let
      # The flake's own packages, built against ITS locked nixpkgs — exactly the
      # drvs upstream CI pushes to hyprland.cachix.org (input deliberately does
      # not follow our nixpkgs; overlay-built packages could never hit the
      # cache). See the hyprland input in flake.nix.
      hyprPkgs = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      # Hyprland desktop, defined directly rather than via
      # `snowglobe-lib.desktop.hyprland.enable`. That module's only unique
      # contribution we want is `programs.hyprland` + uwsm; it also force-enables
      # hyprlock (which auto-enables hypridle via nixpkgs' hyprlock module) plus
      # kitty/dolphin/hyprlauncher — none of which we use (ghostty terminal,
      # fuzzel/Noctalia launcher, Noctalia lock). hyprlock came from nixpkgs and
      # broke the build whenever the hyprland flake's hyprutils overlay outpaced
      # it. See docs/hyprland.md.
      #
      # nebula has no other desktop now (niri removed), so we also assert the
      # shared snowglobe desktop layer here — previously this came for free from
      # the niri module. `snowglobe-lib.desktop.enable` gates desktop.nix, which
      # provides xdg portals, pipewire, bluetooth, screenshot/clipboard tools
      # (grim/slurp/wl-clipboard), swaync, fonts, the ly greeter, hardware.graphics,
      # NIXOS_OZONE_WL, etc. (see snowglobe nixosModules/snowglobe-lib/desktop.nix).
      snowglobe-lib.system.hasDesktop = true;
      snowglobe-lib.desktop = {
        enable = true;
        installWaylandDeps = true;
      };

      programs.hyprland = {
        enable = true;
        withUWSM = true; # provides the `hyprland-uwsm` session (services.displayManager.defaultSession)
        package = hyprPkgs.hyprland;
        portalPackage = hyprPkgs.xdg-desktop-portal-hyprland;
      };

      # Substitute the hypr* stack from upstream's cache instead of building it.
      # CI gets the same pair via extra-nix-config in ci.yml; both lists merge
      # with the defaults.
      nix.settings = {
        substituters = [ "https://hyprland.cachix.org" ];
        trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
      };

      # Launcher used by the Hyprland keybinds (home/hyprland programs.lua:
      # menu = "fuzzel"). Was a default of snowglobe's niri module; assert it
      # directly now that niri is gone.
      programs.fuzzel.enable = true;
    };
}
