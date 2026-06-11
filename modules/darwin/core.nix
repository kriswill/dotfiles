# Core nix-darwin system configuration (was modules/darwin/mixins/default.nix).
# Declares the darwin-side `kriswill.enable` master toggle and the always-on
# system baseline. Sibling darwin features are now separate flake-parts modules
# auto-imported by import-tree, so the old `lib.autoImport` is gone.
{
  flake.modules.darwin.core =
    {
      self,
      pkgs,
      lib,
      ...
    }:
    {
      options.kriswill.enable = lib.mkEnableOption "Kris' custom darwin modules";
      config = {
        kriswill = {
          homebrew.enable = lib.mkDefault true;
          ghostty.enable = lib.mkDefault true;
          macos-defaults.enable = lib.mkDefault true;
          dotfiles-stow.enable = lib.mkDefault true;
          tmux.enable = lib.mkDefault true;
          zsh.enable = lib.mkDefault true;
          neovim.enable = lib.mkDefault true;
          fastfetch.enable = lib.mkDefault true;
        };
        system = {
          # Used for backwards compatibility, please read the changelog before changing.
          # $ darwin-rebuild changelog
          stateVersion = 5;
          # Set Git commit hash for darwin-version.
          configurationRevision = self.rev or self.dirtyRev or null;
          #
          primaryUser = "k";
        };

        environment = {
          # $ nix-env -qaP | grep wget
          systemPackages = [
            pkgs.iproute2mac # ip command (like linux)
            pkgs.home-manager
            pkgs.pstree
          ];
          shellAliases =
            let
              nh = lib.getExe pkgs.nh;
            in
            {
              nrs = "NH_NO_CHECKS=1 ${nh} darwin switch ~/src/dotfiles";
              nrt = "NH_NO_CHECKS=1 ${nh} darwin test ~/src/dotfiles";
            };
          etc."pam.d/sudo_local".text = ''
            # Allow for touch ID to work for sudo, inside of tmux
            auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so ignore_ssh
            auth       sufficient     pam_tid.so
          '';
        };

        security.pam.services.sudo_local.touchIdAuth = true;

        # Disable documentation generation to avoid builtins.toFile warnings
        # with custom module options
        documentation.enable = false;

        # nix repl -f '<nixpkgs>'
        # > nerd-fonts.<tab>
        fonts.packages = builtins.attrValues {
          inherit (pkgs.nerd-fonts)
            victor-mono
            sauce-code-pro
            jetbrains-mono
            ;
        };

        programs = {
          fish.enable = true;
          zsh.enable = true;
          nh.enable = true;
        };

        users.users.k.openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy"
        ];

        # Cannot let nix-darwin control nix when using determinate
        nix.enable = lib.mkForce false;
        nixpkgs = {
          config.allowUnfree = false;
        };
      };
    };
}
