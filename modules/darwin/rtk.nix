# rtk — CLI proxy that filters dev command output (git, grep, cargo, npm,
# docker, aws, …) before it reaches an LLM's context. Derivation lives in
# pkgs/rtk.nix, exposed as pkgs.rtk via the rtk overlay.
#
# On macOS rtk resolves its user-global config/filters via Rust's
# `dirs::config_dir()` = ~/Library/Application Support/rtk (XDG is ignored),
# so the stowed ~/.config/rtk/{config,filters}.toml would never be read here.
# Bridge with per-file symlinks — the dir itself stays real because rtk also
# writes mutable data (history.db) beside them.
{
  flake.modules.darwin.rtk =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.rtk ];

      # Order 1600: after dotfiles-stow (1500) has populated ~/.config/rtk.
      # Run as the user so the dir isn't root-owned.
      system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
        /usr/bin/sudo -u k --set-home /bin/sh -c \
          'mkdir -p "/Users/k/Library/Application Support/rtk" && \
           ln -sfn /Users/k/.config/rtk/config.toml "/Users/k/Library/Application Support/rtk/config.toml" && \
           ln -sfn /Users/k/.config/rtk/filters.toml "/Users/k/Library/Application Support/rtk/filters.toml"'
      '';
    };
}
