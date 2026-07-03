# Kris' tmux (system-level port of the old home-manager module).
#
#  * The static config — tmux.conf and the tmux-which-key `config.yaml` — lives
#    in the stow tree (home/tmux/.config/tmux/...) and is symlinked into ~ by
#    dotfiles-stow.nix (the live, editable repo copy rather than a /nix/store
#    snapshot).
#  * tmux.conf sources ~/.config/tmux/plugins.conf, which must reference the
#    tmux-which-key plugin's runtime path in the /nix/store — a value only Nix
#    knows. That one file can't be a static stow symlink, so we generate it here
#    and link it during activation.
{
  flake.modules.darwin.tmux =
    { lib, pkgs, ... }:
    let
      whichKey = pkgs.tmuxPlugins.tmux-which-key;

      # Equivalent to the old home-manager module's generated `plugins.conf`.
      pluginsConf = pkgs.writeText "tmux-plugins.conf" ''
        set -g @tmux-which-key-xdg-enable 1
        run-shell 'mkdir -p ~/.local/share/tmux/plugins/tmux-which-key && touch ~/.local/share/tmux/plugins/tmux-which-key/init.tmux'
        run-shell ${whichKey.rtp}
      '';
    in
    {
      environment.systemPackages = [ pkgs.tmux ];

      # Order 1600: after dotfiles-stow (1500) has populated ~/.config/tmux.
      # Run as the user so the dir isn't root-owned; `ln -sfn` replaces any
      # stale link so the store path tracks rebuilds.
      system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
        /usr/bin/sudo -u k --set-home /bin/sh -c \
          'mkdir -p /Users/k/.config/tmux && ln -sfn ${pluginsConf} /Users/k/.config/tmux/plugins.conf'
      '';
    };
}
