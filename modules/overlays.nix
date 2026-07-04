# Nixpkgs overlays, exposed as flake outputs and consumed by the host modules
# via `nixpkgs.overlays = builtins.attrValues config.flake.overlays`.
#
# Every host (darwin and nixos) applies the whole set: overlays that only make
# sense on one OS must either be internally platform-guarded (see
# overlays/podman.nix) or merely ADD lazy attrs that the other OS never
# evaluates (hyprland-packages, drop-alacritty-terminfo).
{ inputs, ... }:
{
  flake.overlays = {
    kitten = import ../overlays/kitten.nix;
    direnv = import ../overlays/direnv.nix;
    dots-adopt = import ../overlays/dots-adopt.nix;
    podman = import ../overlays/podman.nix;
    cbissue = import ../overlays/cbissue.nix;
    cbissues = import ../overlays/cbissues.nix;
    flatpak-user = import ../overlays/flatpak-user.nix;
    gh-config = import ../overlays/gh-config.nix;
    gh-op = import ../overlays/gh-op.nix;
    helium-config = import ../overlays/helium-config.nix;
    noctalia-config = import ../overlays/noctalia-config.nix;
    pass-xdg = import ../overlays/pass-xdg.nix;
    wowup = import ../overlays/wowup.nix;
    # ccglass comes from its own flake (./flakes/ccglass), not an in-tree package.
    # Overlays are pure final/prev functions, so we close over `inputs` here rather
    # than importing a separate file. The system is read off prev at eval time.
    ccglass = _final: prev: {
      ccglass = inputs.ccglass.packages.${prev.stdenv.hostPlatform.system}.ccglass;
    };
    # codebase-memory-mcp comes from our kriswill/codebase-memory-mcp `nix` fork.
    codebase-memory-mcp = _final: prev: {
      codebase-memory-mcp =
        inputs.codebase-memory-mcp.packages.${prev.stdenv.hostPlatform.system}.codebase-memory-mcp;
    };
    # tomato's source is a flake input (not a flake itself), so close over
    # `inputs` here like ccglass above.
    tomato = _final: prev: {
      tomato = prev.callPackage ../pkgs/tomato.nix { tomato-src = inputs.tomato; };
    };

    # Hyprland's `default` overlay (hyprland + hyprland-extras) assumes the
    # hypr* build deps (hyprland-guiutils, aquamarine, hyprcursor, hyprgraphics,
    # hyprlang, hyprutils, hyprwire, …) already exist in nixpkgs. They don't in
    # the pinned nixpkgs, so `callPackage ./default.nix` fails with a missing
    # `hyprland-guiutils` argument. `hyprland-packages` is the same hyprland
    # build but with all those dependency overlays applied; pair it with
    # `hyprland-extras` to also get the xdg-desktop-portal-hyprland (xdph) that
    # `default` would have provided.
    hyprland-packages = inputs.hyprland.overlays.hyprland-packages;
    hyprland-extras = inputs.hyprland.overlays.hyprland-extras;

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
