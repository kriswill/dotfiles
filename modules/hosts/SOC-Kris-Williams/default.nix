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
    services.codebase-memory-mcp.enable = false;
    programs.podman-desktop.enable = true;
    # Reached from the home network as `work` (UniFi local DNS record); see
    # modules/darwin/remote-login.nix for why both switches need re-applying.
    services.remote-login.enable = true;
    # A second, key-only sshd on port 2122, independent of Remote Login
    # (modules/darwin/agent-remote.nix).
    services.agent-remote.enable = true;

    # Prompt-free commit signing from the shared sops key, as on k
    # (modules/darwin/git-signing-agent). Commits here otherwise go through
    # 1Password's op-ssh-sign, which fails whenever the app is locked.
    # git-signing.yaml is encrypted to this host's age recipient (`soc` in
    # .sops.yaml); without that sops-install-secrets fails to activate.
    # Setup: knowledge/playbooks/git-signing-agent-setup.md.
    services.git-signing-agent = {
      # On only while the key is in the tree, as on k: deleting the file
      # withdraws the key and the host goes back to signing through 1Password.
      enable = builtins.pathExists ../git-signing.yaml;
      publicKey = ../git-signing.pub;
      sopsFile = ../git-signing.yaml;
    };

    # Hexley the platypus on the Nix snowflake (modules/darwin/fastfetch.nix).
    programs.fastfetch.logo = "hexley-nix.png";

    nixpkgs.hostPlatform = "aarch64-darwin";
    nixpkgs.overlays = builtins.attrValues config.flake.overlays;
  };
}
