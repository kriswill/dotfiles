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
    ld64-lld = import ../overlays/ld64-lld.nix; # TEMPORARY, see file header

    direnv = import ../overlays/direnv.nix;
    dots-adopt = import ../overlays/dots-adopt.nix;
    podman = import ../overlays/podman.nix;
    cbissue = import ../overlays/cbissue.nix;
    cbissues = import ../overlays/cbissues.nix;
    flatpak-user = import ../overlays/flatpak-user.nix;
    gh-config = import ../overlays/gh-config.nix;
    git-yazi = import ../overlays/git-yazi.nix; # TEMPORARY, see file header
    gh-op = import ../overlays/gh-op.nix;
    herdr-nav = import ../overlays/herdr-nav.nix;
    helium-config = import ../overlays/helium-config.nix;
    noctalia-config = import ../overlays/noctalia-config.nix;
    pass-xdg = import ../overlays/pass-xdg.nix;
    rtk = import ../overlays/rtk.nix;
    wowup = import ../overlays/wowup.nix;
    # ccglass comes from its own flake (./flakes/ccglass), not an in-tree package.
    # Overlays are pure final/prev functions, so we close over `inputs` here rather
    # than importing a separate file. The system is read off prev at eval time.
    ccglass = _final: prev: {
      ccglass = inputs.ccglass.packages.${prev.stdenv.hostPlatform.system}.ccglass;
    };
    # herdr from the kriswill/herdr staging fork's `custom` branch (upstream
    # tag + our patch commits, currently the ANSI tab-bar command entries
    # rendered by ~/.local/bin/dotbar-usage — see
    # knowledge/decisions/herdr-ansi-tab-bar-entries.md); close over `inputs`
    # like ccglass above.
    # herdr: upstream's flake package (built with ITS nixpkgs/rust-overlay, see
    # flake.nix) plus our patches from overlays/herdr/. The patches touch only
    # src/ (never Cargo.lock), so upstream's cargoLock stays valid.
    herdr = _final: prev: {
      herdr = (inputs.herdr.packages.${prev.stdenv.hostPlatform.system}.herdr).overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ../overlays/herdr/ansi-tab-bar.patch ];
        # Build identity (upstream build_info.rs hooks, read at compile
        # time): `herdr --version` / `herdr status` report e.g.
        # 0.9.0-kriswill-custom.ansi-tab-bar so a glance shows this is our
        # patched build and which patch set it carries. Any channel other
        # than "preview" behaves exactly like stable (update checks compare
        # the plain base version); the `channel:` line in status is the
        # update channel and stays "stable" independently.
        env = (old.env or { }) // {
          HERDR_BUILD_CHANNEL = "kriswill-custom";
          HERDR_BUILD_ID = "ansi-tab-bar";
        };
      });
    };
    # devenv: upstream's source (flake.nix `devenv-src`) plus our patches
    # from overlays/devenv/, evaluated as a flake through flake-compat so it
    # keeps upstream's own lock (see flake.nix for why). `applyPatches` runs
    # on the build platform of the host being evaluated; the resulting
    # `import` is import-from-derivation. Replaces pkgs.devenv wholesale so
    # modules/{darwin,nixos}/devenv.nix keep installing `pkgs.devenv`.
    devenv = _final: prev: {
      devenv =
        let
          patched = prev.applyPatches {
            name = "devenv-source-patched";
            src = inputs.devenv-src;
            patches = [
              ../overlays/devenv/0001-reply-ordering.patch
              ../overlays/devenv/0002-kitty-graphics.patch
            ];
          };
          flake = (import inputs.flake-compat { src = patched; }).defaultNix;
        in
        flake.packages.${prev.stdenv.hostPlatform.system}.devenv;
    };
    # dotbar comes from its flake input (pinned to the nix-flake PR head, see
    # flake.nix); close over `inputs` like ccglass above.
    dotbar = _final: prev: {
      dotbar = inputs.dotbar.packages.${prev.stdenv.hostPlatform.system}.dotbar;
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

    # NO hyprland overlays (dropped with the hyprland nixpkgs un-follow): the
    # overlays rebuilt hyprland + the whole hypr* dep stack against OUR
    # nixpkgs — never matching hyprland.cachix.org — and their bumped hyprutils
    # bled into unrelated nixpkgs packages (hyprpolkitagent), forcing source
    # rebuilds of those too. Hyprland now comes straight from
    # inputs.hyprland.packages in modules/hosts/nebula/hyprland.nix; everything
    # else hypr-adjacent stays pure nixpkgs (Hydra-cached).

    # snowglobe-factory hardcodes `alacritty.terminfo` into environment.systemPackages
    # (for ssh terminfo). Alacritty is otherwise removed on this system, so
    # neutralise its terminfo output to an empty dir to drop the leftover entirely.
    drop-alacritty-terminfo = final: prev: {
      alacritty = prev.alacritty // {
        terminfo = final.emptyDirectory;
      };
    };
  };
}
