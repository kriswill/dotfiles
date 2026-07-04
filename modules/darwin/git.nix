# Kris' git (system-level port of the old home-manager module).
#
# nix-darwin has no programs.git, so the config — ~/.config/git/{config,ignore,
# allowed_signers} — lives in the stow tree (home/git) and is symlinked into ~
# by dotfiles-stow.nix; gh's config.yml is a config/ snapshot (gh rewrites it
# via atomic rename, breaking stow links) synced with gh-config. This module
# just installs the binaries the stowed config invokes by bare name (git, the
# gh credential helper, the git-lfs filters). ripgrep + jq (used by the `loc`
# alias and the podman filter) come from modules/darwin/user-packages.nix.
{
  flake.modules.darwin.git =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # Auto-capture twin of the systemd path unit in modules/nixos/git.nix.
      # launchd's kqueue file-watches are inode-based and gh replaces config.yml
      # via atomic rename, so watch the directory (also catches hosts.yml churn;
      # capture of an unchanged config.yml is a git no-op). ThrottleInterval
      # coalesces bursts without the systemd TriggerLimit failed-state footgun.
      launchd.user.agents.gh-config-capture.serviceConfig = {
        WatchPaths = [ "/Users/${config.system.primaryUser}/.config/gh" ];
        ProgramArguments = [
          (lib.getExe pkgs.gh-config)
          "capture"
        ];
        RunAtLoad = false;
        ThrottleInterval = 10;
      };

      environment.systemPackages = builtins.attrValues {
        inherit (pkgs)
          git
          gh # github CLI + git credential helper
          gh-config # snapshot/restore ~/.config/gh/config.yml <-> config/gh/ (see config/README.md)
          git-lfs # large file storage filters
          difftastic # structural diff for `git difftool` ([difftool "difftastic"] in shared config)
          ;
      };
    };
}
