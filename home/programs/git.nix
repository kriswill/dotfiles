{ pkgs, ... }:

let
  gitConfig = {
    core = {
      editor = "nvim";
      pager = "diff-so-fancy | less --tabs=4 -RFX";
    };
    init.defaultBranch = "main";
    merge = {
      conflictStyle = "diff3";
      tool = "vim_mergetool";
    };
    mergetool."vim_mergetool" = {
      cmd = "nvim -f -c \"MergetoolStart\" \"$MERGED\" \"$BASE\" \"$LOCAL\" \"$REMOTE\"";
      prompt = false;
    };
    pull.rebase = false;
    push.autoSetupRemote = true;
    url = {
      "https://github.com/".insteadOf = "gh:";
      "ssh://git@github.com".pushInsteadOf = "gh:";
      "https://gitlab.com/".insteadOf = "gl:";
      "ssh://git@gitlab.com".pushInsteadOf = "gl:";
    };
  };

  rg = "${pkgs.ripgrep}/bin/rg";
in
{
  home.packages = with pkgs.gitAndTools; [
    diff-so-fancy # git diff with colors
    git-crypt     # git files encryption
    hub           # github command-line client
    tig           # diff and commit view
  ];

  programs.gh.enable = true;

  programs.git = {
    enable = true;
    aliases = {
      amend = "commit --amend -m";
      fixup = "!f(){ git reset --soft HEAD~\${1} && git commit --amend -C HEAD; };f";
      # lines of code
      loc = "!f(){ git ls-files | ${rg} \"\\.\${1}\" | xargs wc -l; };f";
      br = "branch";
      co = "checkout";
      st = "status";
      ls = "log --pretty=format:\"%C(yellow)%h%Cred%d\\\\ %Creset%s%Cblue\\\\ [%cn]\" --decorate";
      ll = "log --pretty=format:\"%C(yellow)%h%Cred%d\\\\ %Creset%s%Cblue\\\\ [%cn]\" --decorate --numstat";
      cm = "commit -m";
      ca = "commit -am";
      dc = "diff --cached";
    };
    extraConfig = gitConfig;
    ignores = [
      "*.direnv"
      "*.envrc"
    ];
    #signing = {
    #  key = "121D4302A64B2261";
    #  signByDefault = true;
    #};
    userEmail = "115474+kriswill@users.noreply.github.com";
    userName = "Kris Williams";
  } // (pkgs.sxm.git or { });
}

