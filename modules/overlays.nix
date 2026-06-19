# Nixpkgs overlays, exposed as flake outputs and consumed by the host module via
# `nixpkgs.overlays = builtins.attrValues config.flake.overlays`. (Ported from
# the old `overlays/default.nix`, which took a `{ flake }` arg; here `inputs` is
# provided directly by flake-parts.)
{ inputs, ... }:
{
  flake.overlays = {
    # Hyprland's `default` overlay (hyprland + hyprland-extras) assumes the
    # hypr* build deps (hyprland-guiutils, aquamarine, hyprcursor, hyprgraphics,
    # hyprlang, hyprutils, hyprwire, …) already exist in nixpkgs. They don't in
    # the snowglobe-pinned nixpkgs, so `callPackage ./default.nix` fails with a
    # missing `hyprland-guiutils` argument. `hyprland-packages` is the same
    # hyprland build but with all those dependency overlays applied; pair it with
    # `hyprland-extras` to also get the xdg-desktop-portal-hyprland (xdph) that
    # `default` would have provided.
    hyprland-packages = inputs.hyprland.overlays.hyprland-packages;
    hyprland-extras = inputs.hyprland.overlays.hyprland-extras;

    # add your custom packages
    my-packages =
      final: _prev:
      import ../packages {
        pkgs = final;
        inherit inputs;
      };

    # snowglobe-lib hardcodes `alacritty.terminfo` into environment.systemPackages
    # (for ssh terminfo). Alacritty is otherwise removed on this system, so
    # neutralise its terminfo output to an empty dir to drop the leftover entirely.
    drop-alacritty-terminfo = final: prev: {
      alacritty = prev.alacritty // {
        terminfo = final.emptyDirectory;
      };
    };
  };
}
