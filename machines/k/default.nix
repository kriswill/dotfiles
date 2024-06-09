#
# k - my personal macbook pro M1 max, 64GB RAM
#
{ pkgs, self, inputs, outputs, ... }: {
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    home-manager
  ];
  security.pam.enableSudoTouchIdAuth = true;
  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;


  # Necessary for using flakes on this system.
  # nix.settings.experimental-features = "nix-command flakes";
  programs.zsh.enable = true;

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # The platform the configuration will be used on.
  nix = {
    package = pkgs.unstable.nix;
  };
  # nixpkgs = {
  #   hostPlatform = "aarch64-darwin";
  #   overlays = [
  #     inputs.nur.overlay
  #     outputs.overlays.nixpkgs-unstable # pkgs.unstable.*
  #   ];
  #   config = {
  #     # Allow unfree packages
  #     allowUnfree = true;
  #     allowUnsupportedSystem = true;
  #   };
  # };
}