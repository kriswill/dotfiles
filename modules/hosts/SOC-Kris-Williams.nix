# SOC-Kris-Williams - my work Apple M2 Pro, 32GB RAM
# hostname enforced by IT
{ config, ... }:
{
  configurations.darwin.SOC-Kris-Williams.module = {
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
              diffnav # git diff pager (config: home-manager/diffnav.nix)
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
      alias-en0.enable = true;
      dnsmasq.enable = true;
      apple-container.enable = true;
      podman-desktop.enable = true;
    };

    nixpkgs.hostPlatform = "aarch64-darwin";
    nixpkgs.overlays = builtins.attrValues config.flake.overlays;
  };
}
