{
  config,
  pkgs,
  ...
}: let
  cfg = config.programs.git;
  key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy";
in {
  programs.gh = {
    enable = true;
    package = pkgs.gh;
    gitCredentialHelper.enable = true;
  };
  # enable scrolling in git diff
  home.sessionVariables.DELTA_PAGER = "less -R";

  programs.git = {
    enable = true;

    userEmail = "115474+kriswill@users.noreply.github.com";
    userName = "Kris Williams";

    delta = {
      enable = true;
      options.dark = true;
    };

    aliases = {
      a = "add";
      b = "branch";
      c = "commit";
      ca = "commit --amend";
      cm = "commit -m";
      co = "checkout";
      d = "diff";
      ds = "diff --staged";
      p = "push";
      pf = "push --force-with-lease";
      pl = "pull";
      l = "log";
      r = "rebase";
      s = "status --short";
      ss = "status";
      forgor = "commit --amend --no-edit";
      graph = "log --all --decorate --graph --oneline";
      oops = "checkout --";
    };

    ignores = ["*~" "*.swp" "*result*" ".direnv" "node_modules"];

    signing = {
      inherit key;
      signByDefault = true;
      gpgPath = "${pkgs._1password-gui}/bin/op-ssh-sign";
    };

    extraConfig = {
      diff.colorMoved = "default";
      merge.conflictstyle = "diff3";
      pull.rebase = true;
      init.defaultBranch = "main";
      gpg = {
        format = "ssh";
      };
    };



    # config = [
    #   {
    #     user = {
    #       name = "Kris Williams";
    #       email = "115474+kriswill@users.noreply.github.com";
    #       inherit signingkey;
    #     };
    #     init.defaultBranch = "main";
    #   }
    #   { credential."https://github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential"; }
    #   { credential."https://gist.github.com".helper = "!${pkgs.gh}/bin/gh auth git-credential"; }
    #   { gpg.format = "ssh"; }
    #   { gpg."ssh".program = "${pkgs._1password-gui}/bin/op-ssh-sign"; }
    #   { commit.gpgsign = true; }
    # ];
  };
}
