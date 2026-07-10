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
    sops.defaultSopsFile = ./secrets.yaml;
    sops.secrets.sops-smoke-test = { };
    # Dedicated "Developer ID Application" signing identity for automated
    # nas-mount bundle signing (modules/darwin/nas-mount.nix). PEM layout:
    # PKCS#8 private key, then the leaf cert, then the Apple Developer ID G2
    # intermediate — rcodesign pairs the FIRST certificate with the key.
    # Purpose-minted via openssl CSR → Apple portal, NOT the Keychain
    # identity; rotate by minting a new key/CSR/cert and replacing this
    # value (docs/darwin-codesigning.md). owner k: the signing step runs
    # `sudo -u k` inside postActivation, and the default root:staff 0400
    # is unreadable there.
    # UNCOMMENT once the `nas-signing-pem` key exists in secrets.yaml —
    # sops-nix validates at build time that every declared secret exists,
    # so declaring it early breaks the build (verified 2026-07-10). Until
    # then modules/darwin/nas-mount.nix warns-and-skips at activation.
    # sops.secrets.nas-signing-pem.owner = "k";

    # Host-selective features: their modules are imported on every host but
    # ship disabled; enabling here is what mounts them into k.
    services.apple-container.enable = true;
    services.codebase-memory-mcp.enable = true;
    services.nas-mount.enable = true;
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
