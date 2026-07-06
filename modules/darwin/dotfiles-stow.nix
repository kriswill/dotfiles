# Deploy the GNU Stow dotfiles tree (../../home, relative to the repo root) into
# the user's home on every `darwin-rebuild switch`.
#
# Operates on the LIVE repo path, never `${./home}` — interpolating a Nix path
# would copy the tree into a read-only /nix/store path, breaking link stability,
# in-place editing, and the adopt workflow. The symlinks must point at the
# stable, writable repo checkout.
#
# The script body (canonicalization, self-heal, conflict-tolerant restow) is
# shared with the NixOS twin via lib/stow-restow-script.nix.
{
  flake.modules.darwin.dotfiles-stow =
    { lib, pkgs, ... }:
    let
      user = "k";
      home = "/Users/k";
      stowScript = import ../../lib/stow-restow-script.nix {
        inherit pkgs home;
        stowDir = "${home}/src/dotfiles/home";
        # home/ is shared with the NixOS hosts; these packages are Linux-only
        # (Wayland desktop, freedesktop conventions) and must not be stowed on
        # macOS. Everything not listed deploys on both OSes — the right default
        # for cross-platform CLI configs. Mirror list:
        # modules/nixos/dotfiles-stow.nix.
        skip = [
          "desktop-entries" # ~/.local/share/applications launchers
          "diffnav" # nebula's diffnav config (darwin themes delta via its module)
          "fuzzel" # Wayland launcher
          "gtk" # GTK settings
          "hyprland" # Wayland compositor config
          "mimeapps" # freedesktop default-apps registry
          "pupgui" # ProtonUp-Qt (gaming, Linux)
          "python-keyring" # op-backed keyring backend (op path + prompt flow are NixOS-specific; macOS has Keychain)
        ];
        skipReason = "linux-only";
        runAsUser = "/usr/bin/sudo -u ${user} --set-home";
      };
    in
    {
      environment.systemPackages = [
        pkgs.stow
        pkgs.dots-adopt
      ];

      # nix-darwin activation runs as root, with postActivation last. Order
      # 1500 puts this after home-manager's user activation (same hook,
      # default order 1000), so on the first switch HM has already removed
      # its now-orphaned ~/.config symlinks before stow restows over them.
      system.activationScripts.postActivation.text = lib.mkOrder 1500 stowScript;
    };
}
