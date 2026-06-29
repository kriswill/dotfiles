# Kris' ssh (system-level port of the old home-manager module).
#
# nix-darwin has no per-user programs.ssh, so the client config — ForwardAgent +
# the 1Password SSH agent socket, plus the ~/.ssh/config.d/* include — lives in
# the stow tree (home/ssh/.ssh/config) and is symlinked into ~ by
# dotfiles-stow.nix. The ssh binary is macOS's own (/usr/bin/ssh), so there is
# nothing to install; this module only carries the enable toggle.
{
  flake.modules.darwin.ssh =
    {
      lib,
      config,
      ...
    }:
    {
      options.kriswill.ssh.enable = lib.mkEnableOption "Kris' ssh";
      config = lib.mkIf config.kriswill.ssh.enable { };
    };
}
