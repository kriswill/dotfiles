# k - my personal macbook pro M1 max, 64GB RAM
{ config, ... }:
{
  configurations.darwin.k.module = {
    imports = (builtins.attrValues config.flake.modules.darwin) ++ [
      (
        { pkgs, ... }:
        {
          # Host-specific user-level packages (always-on baseline lives in
          # modules/darwin/user-packages.nix).
          users.users.k.packages = builtins.attrValues {
            inherit (pkgs)
              git-crypt # transparent git file encryption
              tig # text-mode git diff/commit viewer
              diffnav # git diff pager (config: modules/darwin/diffnav.nix)
              neovide # neovim GUI
              podman-desktop # config: home/podman-desktop stow tree
              podman
              vfkit # Virtualization.framework helper podman drives for applehv
              k9s # kubernetes TUI
              ;
          };
        }
      )
    ];

    kriswill = {
      enable = true;
      dnsmasq.enable = true;
      apple-container.enable = true;
      podman-desktop.enable = true;

      claude-account-selector = {
        enable = true;
        defaultProfile = "me";
        profiles = [
          "me"
          "work"
        ];
        rules = {
          "/Users/k/src/perforce" = "work";
        };
        # Pin the GUI Claude desktop app to ~/.claude-me (GUI apps can't do the
        # per-$PWD switching the shell wrapper does). See the module README.
        desktopProfile = "me";
      };
    };

    nixpkgs.hostPlatform = "aarch64-darwin";
    nixpkgs.overlays = builtins.attrValues config.flake.overlays;
  };
}
