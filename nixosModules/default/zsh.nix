# The interactive config itself — aliases, vi-mode, and the prompt
# — lives in the stow tree at home/zsh/.config/zsh/.zshrc, symlinked to
# ~/.config/zsh/.zshrc by dotfiles-stow.nix.
{ pkgs, lib, ... }:
let
  home = "/home/k";
  user = "k";
in
{
  programs.zsh = {
    # /etc/zshenv is read first for every shell, so setting ZDOTDIR here puts it
    # in effect before zsh looks for the user .zshrc (and before compinit picks
    # where to drop .zcompdump). Both then land in ~/.config/zsh, not $HOME.
    shellInit = ''
      export ZDOTDIR="$HOME/.config/zsh"
    '';

    # Larger in-memory history; the on-disk file goes under XDG state so it
    # doesn't litter $HOME. (SAVEHIST is raised further in the user .zshrc.)
    histSize = 100000;
    histFile = "$HOME/.local/state/zsh/history";

    # Drop the default `prompt suse`; starship is set in ~/.config/zsh/.zshrc.
    promptInit = lib.mkForce "";
  };

  # zsh / less won't create these parent dirs themselves — do it declaratively
  # (tmpfiles, not an activation script, to avoid boot-time activation footguns).
  systemd.tmpfiles.rules = [
    "d ${home}/.config/zsh 0755 ${user} users - -"
    "d ${home}/.local/state/zsh 0700 ${user} users - -"
    "d ${home}/.local/state/less 0700 ${user} users - -"
  ];

  # Tools the user's zsh config invokes. eza/bat/fzf/fastfetch/direnv already
  # come from snowglobe-lib, so only the additions live here.
  environment.systemPackages = builtins.attrValues {
    inherit (pkgs)
      starship # prompt
      zoxide # `j` smart-cd
      hstr # Ctrl-R history picker
      ;
    inherit (pkgs.bat-extras) batman; # man-page colorizer (compdef batman=man)
  };

  # Keep `less` history (used by bat / man pagers) out of $HOME as well.
  environment.sessionVariables.LESSHISTFILE = "${home}/.local/state/less/history";
}
