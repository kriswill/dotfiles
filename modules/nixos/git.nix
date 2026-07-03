# Git + the tools the stow-managed git config invokes by bare name — the NixOS
# twin of modules/darwin/git.nix (plus the diff stack nebula previously
# installed ad hoc in its host configuration.nix). The config itself —
# ~/.config/git/{config,ignore,allowed_signers} and ~/.config/gh/config.yml —
# lives in the stow tree (home/git, home/gh). ripgrep + jq (the `loc` alias and
# the podman filter) come from the hacker-mode profile / user packages.
{
  flake.modules.nixos.git =
    { pkgs, ... }:
    {
      environment.systemPackages = builtins.attrValues {
        inherit (pkgs)
          git
          gh # github CLI + git credential helper
          git-lfs # large file storage filters ([filter "lfs"] in shared config)
          delta # diff renderer diffnav shells out to (styled via [delta] in git config)
          diffnav # git diff pager with a file tree (git pager.diff/show); wraps delta
          difftastic # structural diff for `git difftool` ([difftool "difftastic"])
          ;
      };
    };
}
