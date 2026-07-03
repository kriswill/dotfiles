# Kris' git (system-level port of the old home-manager module).
#
# nix-darwin has no programs.git, so the config — ~/.config/git/{config,ignore,
# allowed_signers} and ~/.config/gh/config.yml — lives in the stow tree
# (home/git, home/gh) and is symlinked into ~ by dotfiles-stow.nix. This module
# just installs the binaries the stowed config invokes by bare name (git, the
# gh credential helper, the git-lfs filters). ripgrep + jq (used by the `loc`
# alias and the podman filter) come from modules/darwin/user-packages.nix.
{
  flake.modules.darwin.git =
    { pkgs, ... }:
    {
      environment.systemPackages = builtins.attrValues {
        inherit (pkgs)
          git
          gh # github CLI + git credential helper
          git-lfs # large file storage filters
          ;
      };
    };
}
