# Kris' htop (system-level port of the old home-manager programs.htop).
#
# home-manager rendered programs.htop.settings into an immutable (read-only)
# ~/.config/htop/htoprc symlinked from the store. nix-darwin has no
# programs.htop, so we reproduce that exactly: generate the same htoprc with
# writeText and link it during activation. Keeping it a store symlink (rather
# than a stow file) preserves the immutability — htop rewrites htoprc on quit,
# which against a writable stow link would churn the repo on every run.
{
  flake.modules.darwin.htop =
    { lib, pkgs, ... }:
    let
      # Equivalent to the old module's generated htoprc: the meter/field layout
      # is home-manager's default `fields` line; the rest are the three settings
      # that were set explicitly (sort by CPU%, descending, no program path).
      htoprc = pkgs.writeText "htoprc" ''
        fields=0 48 17 18 38 39 2 46 47 49 1
        show_program_path=0
        sort_direction=1
        sort_key=PERCENT_CPU
      '';
    in
    {
      environment.systemPackages = [ pkgs.htop ];

      # Order 1600: after dotfiles-stow (1500) has created ~/.config. Run as
      # the user so the dir/link aren't root-owned; ln -sfn replaces any stale
      # link so the store path tracks rebuilds.
      system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
        /usr/bin/sudo -u k --set-home /bin/sh -c \
          'mkdir -p /Users/k/.config/htop && ln -sfn ${htoprc} /Users/k/.config/htop/htoprc'
      '';
    };
}
