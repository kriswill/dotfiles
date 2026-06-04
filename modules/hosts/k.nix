# k - my personal macbook pro M1 max, 64GB RAM
{ config, ... }:
{
  configurations.darwin.k.module = {
    imports = builtins.attrValues config.flake.modules.darwin;

    kriswill = {
      enable = true;
      dnsmasq.enable = true;
    };

    # Wrap users.k in a function so the inner `config` is this user's home-manager
    # config (needed for config.home.homeDirectory); the outer `config` above is the
    # flake-parts config and has no `home`.
    home-manager.users.k = { config, ... }: {
      kriswill.podman-desktop.enable = true;

      kriswill.claude-account-selector = {
        enable = true;
        defaultProfile = "me";
        profiles = [
          "me"
          "work"
        ];
        rules = {
          "${config.home.homeDirectory}/src/perforce" = "work";
        };
      };
    };

    nixpkgs.hostPlatform = "aarch64-darwin";
    nixpkgs.overlays = builtins.attrValues config.flake.overlays;
  };
}
