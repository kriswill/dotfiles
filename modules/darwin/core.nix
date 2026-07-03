# Core nix-darwin system configuration: the always-on baseline shared by every
# darwin host. Sibling darwin features are separate flake-parts modules
# auto-imported by import-tree and mounted ungated — a host that imports a
# module gets it, period (host-selective features live under modules/hosts/).
{
  flake.modules.darwin.core =
    {
      self,
      pkgs,
      lib,
      ...
    }:
    {
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
          pkgs.pstree
          # markdown reader; config is stow-managed (home/glow/), and the
          # yazi previewer invokes it by bare name
          pkgs.glow
          # MCP server for codebase memory/graph indexing (flakes/codebase-memory-mcp)
          pkgs.codebase-memory-mcp
        ];
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
}
