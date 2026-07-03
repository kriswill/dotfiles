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
              podman # bundles its vfkit + gvproxy machine helpers (pkgs/podman.nix)
              k9s # kubernetes TUI
              ;
          };
        }
      )
    ];

    # Host-selective features: their modules are imported on every host but
    # ship disabled; enabling here is what mounts them into k.
    services.apple-container.enable = true;
    services.codebase-memory-mcp.enable = true;
    programs.podman-desktop.enable = true;

    programs.claude-account-selector = {
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

    nixpkgs.hostPlatform = "aarch64-darwin";
    nixpkgs.overlays = builtins.attrValues config.flake.overlays;
  };
}
