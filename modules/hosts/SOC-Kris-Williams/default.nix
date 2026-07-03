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
              podman # bundles its vfkit + gvproxy machine helpers (pkgs/podman.nix)
              k9s # kubernetes TUI
              ;
          };
        }
      )
    ];

    # Host-selective features: their modules are imported on every host but
    # ship disabled; enabling here is what mounts them into this host.
    # alias-en0 is host-specific and lives beside this file (./alias-en0.nix).
    services.apple-container.enable = true;
    services.codebase-memory-mcp.enable = true;
    programs.podman-desktop.enable = true;

    nixpkgs.hostPlatform = "aarch64-darwin";
    nixpkgs.overlays = builtins.attrValues config.flake.overlays;
  };
}
