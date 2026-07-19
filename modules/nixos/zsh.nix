{
  flake.modules.nixos.zsh =
    { pkgs, lib, ... }:
    let
      home = "/home/k";
      user = "k";
    in
    {
      programs.zsh = {
        shellInit = ''
          export ZDOTDIR="$HOME/.config/zsh"
        '';

        # Larger in-memory history; the on-disk file goes under XDG state so it
        # doesn't litter $HOME. (SAVEHIST is raised further in the user .zshrc.)
        histSize = 100000;
        histFile = "$HOME/.local/state/zsh/history";

        promptInit = lib.mkForce "";
      };

      # zsh / less won't create these parent dirs themselves — do it declaratively
      # (tmpfiles, not an activation script, to avoid boot-time activation footguns).
      systemd.tmpfiles.rules = [
        "d ${home}/.config/zsh 0755 ${user} users - -"
        "d ${home}/.local/state/zsh 0700 ${user} users - -"
        "d ${home}/.local/state/less 0700 ${user} users - -"
      ];

      environment.systemPackages = builtins.attrValues {
        inherit (pkgs)
          eza # ls replacement (alias chain)
          starship # prompt
          zoxide # `j` smart-cd
          atuin # Ctrl-R history search (fuzzy, syncless)
          ;
        inherit (pkgs.bat-extras) batman; # man-page colorizer (compdef batman=man)
      };

      environment.sessionVariables.LESSHISTFILE = "${home}/.local/state/less/history";
    }

  ;
}
