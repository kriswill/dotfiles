# Kris' zsh (system-level port of the old home-manager module).
#
# The interactive config itself — aliases, vi-mode, and the prompt — lives in
# the stow tree at home/zsh/.config/zsh/.zshrc, symlinked to
# ~/.config/zsh/.zshrc by dotfiles-stow.nix. `programs.zsh.enable` is already
# set in core.nix; this module points it at the stowed rc and installs the
# tools the rc invokes.
{
  flake.modules.darwin.zsh =
    { lib, pkgs, ... }:
    {
      programs.zsh = {
        # /etc/zshenv is read first for every shell, so setting ZDOTDIR here puts
        # it in effect before zsh looks for the user .zshrc (and before compinit
        # picks where to drop .zcompdump). Both then land in ~/.config/zsh.
        shellInit = ''
          export ZDOTDIR="$HOME/.config/zsh"
        '';

        # Larger in-memory history; the on-disk file goes under XDG state so it
        # doesn't litter $HOME. (SAVEHIST is raised further in the user .zshrc.)
        histSize = 100000;
        histFile = "$HOME/.local/state/zsh/history";

        # Drop the default `prompt suse`; starship is set in ~/.config/zsh/.zshrc.
        promptInit = lib.mkForce "";

        # Previously provided by home-manager's programs.zsh; nix-darwin sources
        # both from /etc/zshrc.
        enableAutosuggestions = true;
        enableSyntaxHighlighting = true;
      };

      # Tools the user's .zshrc invokes by bare name.
      environment.systemPackages = builtins.attrValues {
        inherit (pkgs)
          eza # ls replacement (alias chain)
          starship # prompt
          zoxide # `j` smart-cd
          hstr # Ctrl-R history picker
          ;
        inherit (pkgs.bat-extras) batman; # man-page colorizer (compdef batman=man)
      };

      # Keep `less` history (used by bat / man pagers) out of $HOME as well.
      environment.variables.LESSHISTFILE = "/Users/k/.local/state/less/history";

      # zsh / less won't create these parent dirs themselves. Order 1600:
      # after dotfiles-stow (1500); run as the user so they aren't root-owned.
      system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
        /usr/bin/sudo -u k --set-home /bin/sh -c \
          'mkdir -p /Users/k/.config/zsh /Users/k/.local/state/zsh /Users/k/.local/state/less'
      '';
    };
}
