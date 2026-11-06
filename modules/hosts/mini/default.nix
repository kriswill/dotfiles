# mini - my personal mac mini M1, 16GB RAM
{ config, ... }:
{
  configurations.darwin.mini.module = {
    imports = (builtins.attrValues config.flake.modules.darwin) ++ [
      (
        { pkgs, ... }:
        {
          # Host-specific user-level packages (always-on baseline lives in
          # modules/darwin/user-packages.nix). No podman stack on mini.
          users.users.k.packages = builtins.attrValues {
            inherit (pkgs)
              git-crypt # transparent git file encryption
              tig # text-mode git diff/commit viewer
              diffnav # git diff pager (config: home-manager/diffnav.nix)
              neovide # neovim GUI
              ;
          };
        }
      )
    ];

    # Hexley the platypus on the Nix snowflake (modules/darwin/fastfetch.nix).
    programs.fastfetch.logo = "hexley-nix.png";

    # Prompt-free commit signing for headless use (Claude under herdr core):
    # a mini-only key, read from 1Password by a service account into a
    # root-loaded ssh-agent (modules/darwin/git-signing-agent). Setup,
    # rotation and revocation: knowledge/playbooks/git-signing-agent-setup.md.
    services.git-signing-agent = {
      enable = true;
      publicKey = ./git-signing.pub;
      sopsFile = ./secrets.yaml;
      opItem = "mini-automation/mini git signing key";
    };

    nixpkgs.hostPlatform = "aarch64-darwin";
    nixpkgs.overlays = builtins.attrValues config.flake.overlays;
  };
}
