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

    # sops-nix (machinery: modules/darwin/sops.nix; recipients: .sops.yaml).
    # smoke-test secret proves decryption end-to-end on this host — replace
    # with real secrets as they arrive; edit with `sops modules/hosts/k/secrets.yaml`.
    sops = {
      defaultSopsFile = ./secrets.yaml;
      secrets.sops-smoke-test = { };
      # Private ssh Host entries, kept out of the public repo. Lands as a
      # symlink in ~/.ssh/config.d/, which home/ssh's config Include-globs.
      # owner k: ssh runs as the user and the default root:staff 0400 is
      # unreadable there. Edit with:
      #   SOPS_AGE_KEY=$(sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key) \
      #     sops modules/hosts/k/ssh-hosts.yaml
      secrets.ssh-private-hosts = {
        sopsFile = ./ssh-hosts.yaml;
        owner = "k";
        path = "/Users/k/.ssh/config.d/private-hosts";
      };
    };

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
      # Backstop for launches that miss CLAUDE_CONFIG_DIR entirely (launchd env
      # lost to a login race / var-less relaunch): ~/.claude → ~/.claude-me.
      fallbackProfile = "me";
    };

    nixpkgs.hostPlatform = "aarch64-darwin";
    nixpkgs.overlays = builtins.attrValues config.flake.overlays;
  };
}
