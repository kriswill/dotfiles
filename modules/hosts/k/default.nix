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
              socat # TCP port plumbing tool
              ;
          };

          # GUI apps go in systemPackages: nix-darwin copies only those into
          # /Applications/Nix Apps, where Spotlight indexes them.
          environment.systemPackages = [
            # P4V/P4Admin/P4Merge, bumped past nixpkgs' 2026.1. dontStrip: stdenv
            # strips Applications/ on darwin, invalidating Perforce's notarized
            # signature. Perforce reissues patch builds at the same URL, so a
            # hash mismatch here means a new 26.3 build shipped.
            (pkgs.p4v.overrideAttrs {
              version = "2026.3";
              dontStrip = true;
              src = pkgs.fetchurl {
                url = "https://cdist2.perforce.com/perforce/r26.3/bin.macosx12u/P4V.dmg";
                hash = "sha256-oHTNzypdtcEzT7sYGIaToTKLsUKqQOroxrB9jrfePQY=";
              };
            })
          ];
        }
      )
    ];

    # sops-nix (machinery: modules/darwin/sops.nix; recipients: .sops.yaml).
    # smoke-test secret proves decryption end-to-end on this host — replace
    # with real secrets as they arrive; edit with `sops modules/hosts/k/secrets.yaml`.
    sops = {
      defaultSopsFile = ./secrets.yaml;
      secrets.sops-smoke-test = { };
    };

    # Host-selective features: their modules are imported on every host but
    # ship disabled; enabling here is what mounts them into k.
    services.apple-container.enable = true;
    programs.ssh-private-hosts.enable = true;
    services.codebase-memory-mcp.enable = true;
    programs.podman-desktop.enable = true;
    # Chrome is gone for good: Helium is the browser; Google's updater kept
    # reinstalling Chrome over the Helium shim (modules/darwin/helium-chrome-shim.nix).
    programs.helium-chrome-shim.purgeGoogleChrome = true;

    # Hexley the platypus on the Nix snowflake (modules/darwin/fastfetch.nix).
    programs.fastfetch.logo = "hexley-nix.png";

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
