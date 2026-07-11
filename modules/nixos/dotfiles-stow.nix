{
  flake.modules.nixos.dotfiles-stow =
    # Deploy the GNU Stow dotfiles tree (../../home, relative to the repo root) into
    # the user's home on every `nixos-rebuild switch`.
    #
    # Operates on the LIVE repo path, never `${./home}` — interpolating a Nix path
    # would copy the tree into a read-only /nix/store path, breaking link stability,
    # in-place editing, and the adopt workflow. The symlinks must point at the
    # stable, writable repo checkout.
    #
    # The script body (canonicalization, self-heal, conflict-tolerant restow) is
    # shared with the darwin twin via lib/stow-restow-script.nix.
    { pkgs, ... }:
    let
      user = "k";
      home = "/home/k";
      stowScript = import ../../lib/stow-restow-script.nix {
        inherit pkgs home;
        stowDir = "${home}/src/dotfiles/home";
        # home/ is shared with the darwin hosts; these packages are macOS-only
        # (Homebrew apps, Library/ paths, 1Password agent-socket paths) and must
        # not be stowed on NixOS. Everything not listed deploys on both OSes —
        # the right default for cross-platform CLI configs. Mirror list:
        # modules/darwin/dotfiles-stow.nix.
        skip = [
          "glow" # macOS Library/Preferences path
          "karabiner" # macOS-only hardware remapper
          "kitty" # not installed on nebula (ghostty is the terminal)
          "oksh" # not installed on nebula
          "podman-desktop" # darwin podman stack only
          "yazi" # yazi module (plugins/flavor links) not ported to nixos yet
        ];
        skipReason = "darwin-only";
        runAsUser = "${pkgs.util-linux}/bin/runuser -u ${user} -- env HOME=${home}";
      };
      # Restow churn (self-heal rm + recreate) kills Hyprland's inotify watch on
      # the deleted link, so it never sees the file return and shows a stale
      # "cannot open" error banner. Reload any running instance to clear it.
      hyprReload = ''
        (
        for sock in /run/user/*/hypr/*/.socket.sock; do
          [ -S "$sock" ] || continue
          rundir="''${sock%/hypr/*}"
          sig="''${sock%/.socket.sock}"; sig="''${sig##*/}"
          if XDG_RUNTIME_DIR="$rundir" HYPRLAND_INSTANCE_SIGNATURE="$sig" \
               ${pkgs.hyprland}/bin/hyprctl reload >/dev/null 2>&1; then
            echo "stow: reloaded hyprland ($sig)" >&2
          fi
        done
        )
      '';
    in
    {
      environment.systemPackages = [
        pkgs.stow
        pkgs.dots-adopt
      ];

      system.activationScripts.stowDotfiles = {
        deps = [ "users" ]; # run after user k exists
        text = stowScript + hyprReload;
      };
    };
}
