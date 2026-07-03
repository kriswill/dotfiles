{
  flake.modules.darwin.ghostty =
    { lib, ... }:
    {
      homebrew.casks = [ "ghostty" ];
      environment.variables.TERMINFO_DIRS = [
        "/Applications/Ghostty.app/Contents/Resources/terminfo"
        "/usr/share/terminfo"
      ];

      # Symlink ghostty's terminfo to ~/.terminfo so it's discoverable before
      # TERMINFO_DIRS is set (fixes SSH sessions where the nix-darwin
      # set-environment script runs before env vars are exported). The app
      # bundle path lives outside the repo, so it can't be a stow file; the
      # ghostty config itself is stow-managed (home/ghostty/). Order 1600:
      # after dotfiles-stow (1500), run as the user.
      system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
        /usr/bin/sudo -u k --set-home /bin/ln -sfn \
          /Applications/Ghostty.app/Contents/Resources/terminfo /Users/k/.terminfo
      '';
    };
}
