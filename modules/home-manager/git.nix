{
  lib,
  config,
  pkgs,
  ...
}:

{
  options.kriswill.git.enable = lib.mkEnableOption "Kris' git";

  config = lib.mkIf config.kriswill.git.enable (
    let
      rg = "${pkgs.ripgrep}/bin/rg";
      email = "115474+kriswill@users.noreply.github.com";
      sshPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxqhXoAlCKYNwsB1YrszftURThiCI94oeR0W9EDhrLy";
    in
    {
      home.packages = with pkgs; [
        diff-so-fancy # git diff with colors
        git-crypt # git files encryption
        tig # diff and commit view
      ];

      programs.gh.enable = true;

      xdg.configFile."git/allowed_signers".text = ''
        ${email} ${sshPubKey}
      '';

      programs.git = {
        enable = true;
        ignores = [
          "*.direnv"
          "*.envrc"
          ".DS_Store"
        ];
        settings = {
          alias = {
            amend = "commit --amend -m";
            fixup = "!f(){ git reset --soft HEAD~\${1} && git commit --amend -C HEAD; };f";
            # lines of code
            loc = ''!f(){ git ls-files | ${rg} "\.''${1}" | xargs wc -l; };f'';
            br = "branch";
            co = "checkout";
            st = "status";
            ls = "!git log --pretty=format:'%C(yellow)%h%Cred%d %Creset%s%Cblue [%cn]%Creset %G?' --color=always --decorate \"$@\" | sed 's/ G$/ 🔒/;s/ N$/ ➖/;s/ [BUEXYR]$/ ⚠️/' | less -RFX";
            ll = "!git log --pretty=format:'%C(yellow)%h%Cred%d %Creset%s%Cblue [%cn]%Creset %G?' --color=always --decorate --numstat \"$@\" | sed 's/ G$/ 🔒/;s/ N$/ ➖/;s/ [BUEXYR]$/ ⚠️/' | less -RFX";
            cm = "commit -m";
            ca = "commit -am";
            dc = "diff --cached";
          };
          user = {
            inherit email;
            name = "Kris Williams";
          };
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
            cmd = ''nvim -f -c "MergetoolStart" "$MERGED" "$BASE" "$LOCAL" "$REMOTE"'';
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
          user.signingkey = sshPubKey;
          gpg.format = "ssh";
          gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
          gpg.ssh.allowedSignersFile = "~/.config/git/allowed_signers";
          commit.gpgsign = true;
          tag.gpgsign = true;
        };
      }
      // (pkgs.sxm.git or { });
    }
  );
}
