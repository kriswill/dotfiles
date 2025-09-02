{
  self,
  pkgs,
  lib,
  ...
}:
{
  imports = lib.autoImport ./.;
  options.kriswill.enable = lib.mkEnableOption "Kris' custom darwin modules";
  config = {
    kriswill = {
      homebrew.enable = lib.mkDefault true;
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
        pkgs.iproute2mac
        pkgs.home-manager
      ];
      # ++ [
      #   inputs.fh.packages.${pkgs.stdenv.hostPlatform.system}.default
      # inputs.ghostty.packages.aarch64-darwin.default
      # ];
      shellAliases =
        let
          nh = lib.getExe pkgs.nh;
        in
        {
          # drs = "sudo ${
          #   inputs.darwin.packages.${pkgs.stdenv.hostPlatform.system}.darwin-rebuild
          # }/bin/darwin-rebuild switch --flake ~/src/dotfiles |& ${lib.getExe pkgs.nix-output-monitor}";
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

    # Cannot let nix-darwin control nix when using determinate
    nix.enable = lib.mkForce false;
    nixpkgs = {
      config.allowUnfreePredicate =
        pkg:
        builtins.elem (lib.getName pkg) [
          "claude-code"
        ];
    };
  };
}
