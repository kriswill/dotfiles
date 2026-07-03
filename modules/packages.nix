# Custom package outputs (also surfaced onto `pkgs` for hosts via ./overlays.nix).
# Derivations live in pkgs/ (one file per package, callPackage'd here).
{ inputs, ... }:
{
  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    {
      packages = {
        iv = pkgs.callPackage ../pkgs/iv.nix { };
        dots-adopt = pkgs.callPackage ../pkgs/dots-adopt.nix { };
        # cbissue/cbissues — open/browse Codeberg (Forgejo) issues from the CLI;
        # token via 1Password.
        cbissue = pkgs.callPackage ../pkgs/cbissue.nix { };
        cbissues = pkgs.callPackage ../pkgs/cbissues.nix { };
        # tomato — TOML get/set CLI (toml_edit, comment/format-preserving). Source
        # is the flake input (not a flake itself); built via rustPlatform.
        tomato = pkgs.callPackage ../pkgs/tomato.nix { tomato-src = inputs.tomato; };
        # pass-xdg — drop-in `pass` that defaults PASSWORD_STORE_DIR to
        # $XDG_DATA_HOME/password-store (~/.local/share/password-store).
        pass-xdg = pkgs.callPackage ../pkgs/pass-xdg.nix { };
        # noctalia-config / helium-config — snapshot/restore app-owned configs
        # into config/ without symlinking the live files (atomic-rename saves
        # would break stow links). See config/README.md.
        noctalia-config = pkgs.callPackage ../pkgs/noctalia-config.nix { };
        helium-config = pkgs.callPackage ../pkgs/helium-config.nix { };
        # ccglass is built by its own flake (./flakes/ccglass); re-export it here.
        ccglass = inputs.ccglass.packages.${system}.ccglass;
        # codebase-memory-mcp comes from our kriswill/codebase-memory-mcp `nix` fork.
        codebase-memory-mcp = inputs.codebase-memory-mcp.packages.${system}.codebase-memory-mcp;
      }
      # apple-container is built by its own flake (./flakes/apple-container) and is
      # Apple-Silicon-only; guard so the Linux systems in the root `systems` list
      # don't break eval on this line.
      // lib.optionalAttrs (system == "aarch64-darwin") {
        apple-container = inputs.apple-container.packages.${system}.apple-container;
        # Official prebuilt podman macOS remote client (aarch64-darwin only).
        podman = pkgs.callPackage ../pkgs/podman.nix { };
        # kitten ships as a prebuilt darwin-arm64 binary.
        kitten = pkgs.callPackage ../pkgs/kitten.nix { };
      }
      # Linux-only: wowup wraps an AppImage (needs the appimage runtime);
      # flatpak-user shims a Linux-only package manager.
      // lib.optionalAttrs (lib.hasSuffix "linux" system) {
        flatpak-user = pkgs.callPackage ../pkgs/flatpak-user.nix { };
        # wowPath (the Steam/Proton prefix) defaults inside pkgs/wowup.nix so
        # the overlay and this output stay in sync.
        wowup = pkgs.callPackage ../pkgs/wowup.nix { };
      };
    };
}
