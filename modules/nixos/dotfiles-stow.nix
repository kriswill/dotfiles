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
          "ssh" # IdentityAgent points at the macOS 1Password socket
          "yazi" # yazi module (plugins/flavor links) not ported to nixos yet
        ];
        skipReason = "darwin-only";
        runAsUser = "${pkgs.util-linux}/bin/runuser -u ${user} -- env HOME=${home}";
      };
    in
    {
      environment.systemPackages = [
        pkgs.stow
        pkgs.dots-adopt
      ];

      system.activationScripts.stowDotfiles = {
        deps = [ "users" ]; # run after user k exists
        text = stowScript;
      };
    };
}
