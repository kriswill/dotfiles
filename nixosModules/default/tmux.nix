# Kris' tmux.
#
# The cross-host dotfiles (`main` branch) configure tmux via a home-manager
# module. nebula does NOT run home-manager, so this is the plain-NixOS port:
#
#  * The static config — tmux.conf and the tmux-which-key `config.yaml` — lives
#    in the stow tree (home/tmux/.config/tmux/...) and is symlinked into ~ by
#    dotfiles-stow.nix, mirroring home-manager's `mkOutOfStoreSymlink` (the live,
#    editable repo copy rather than a /nix/store snapshot).
#  * tmux.conf sources ~/.config/tmux/plugins.conf, which must reference the
#    tmux-which-key plugin's runtime path in the /nix/store — a value only Nix
#    knows. That one file can't be a static stow symlink, so we generate it here
#    and materialise it with systemd.tmpfiles (declarative; no activation-script
#    boot-abort footguns).
{ pkgs, ... }:
let
  home = "/home/k";
  user = "k";

  whichKey = pkgs.tmuxPlugins.tmux-which-key;

  # Equivalent to the home-manager module's generated `plugins.conf`.
  pluginsConf = pkgs.writeText "tmux-plugins.conf" ''
    set -g @tmux-which-key-xdg-enable 1
    run-shell 'mkdir -p ~/.local/share/tmux/plugins/tmux-which-key && touch ~/.local/share/tmux/plugins/tmux-which-key/init.tmux'
    run-shell ${whichKey.rtp}
  '';
in
{
  environment.systemPackages = [ pkgs.tmux ];

  # Own the tmux config dir as k (so stow can deploy tmux.conf / config.yaml into
  # it regardless of tmpfiles-vs-stow ordering), then drop the generated
  # plugins.conf in beside the stow-managed symlinks. `L+` replaces any stale
  # link so the store path tracks rebuilds.
  systemd.tmpfiles.rules = [
    "d ${home}/.config/tmux 0755 ${user} users - -"
    "L+ ${home}/.config/tmux/plugins.conf - - - - ${pluginsConf}"
  ];
}
