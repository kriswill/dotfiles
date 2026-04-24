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
        git-crypt # git files encryption
        tig # diff and commit view
      ];

      programs.gh.enable = true;

      xdg.configFile."git/allowed_signers".text = ''
        ${email} ${sshPubKey}
      '';

      programs.git = {
        enable = true;
        signing.format = null;
        ignores = [
          "*.direnv"
          "*.envrc"
          ".DS_Store"
        ];
        settings = {
          user = {
            inherit email;
            name = "Kris Williams";
            signingkey = sshPubKey;
          };
          core.editor = "nvim";
          init.defaultBranch = "main";
          pull.rebase = false;
          push.autoSetupRemote = true;
          merge = {
            conflictStyle = "zdiff3";
            tool = "vim_mergetool";
          };
          mergetool."vim_mergetool" = {
            cmd = ''nvim -f -c "MergetoolStart" "$MERGED" "$BASE" "$LOCAL" "$REMOTE"'';
            prompt = false;
          };
          gpg.format = "ssh";
          gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
          gpg.ssh.allowedSignersFile = "~/.config/git/allowed_signers";
          commit.gpgsign = true;
          tag.gpgsign = true;
          url = {
            "https://github.com/".insteadOf = "gh:";
            "ssh://git@github.com".pushInsteadOf = "gh:";
            "https://gitlab.com/".insteadOf = "gl:";
            "ssh://git@gitlab.com".pushInsteadOf = "gl:";
          };
          filter."normalize-podman-settings" = {
            clean = ''${pkgs.jq}/bin/jq 'del(."window.bounds", ."titleBar.searchBar".remindAt, ."statusbarProviders.showProviders".remindAt)' '';
            smudge = "cat";
          };
          alias = {
            amend = "commit --amend -m";
            fixup = "!f(){ git reset --soft HEAD~\${1} && git commit --amend -C HEAD; };f";
            # lines of code
            loc = ''!f(){ git ls-files | ${rg} "\.''${1}" | xargs wc -l; };f'';
            br = "branch";
            co = "checkout";
            st = "status";
            ls = "!git log --pretty=format:'%C(yellow)%h%Cred%d %Creset%s%Cblue [%cn]%Creset %G?' --color=always --decorate \"$@\" | sed 's/ G$/ 🔒/;s/ N$/ ➖/;s/ [UE]$/ 🔑/;s/ [BXYR]$/ ⚠️/' | less -RFX";
            ll = "!git log --pretty=format:'%C(yellow)%h%Cred%d %Creset%s%Cblue [%cn]%Creset %G?' --color=always --decorate --numstat \"$@\" | sed 's/ G$/ 🔒/;s/ N$/ ➖/;s/ [UE]$/ 🔑/;s/ [BXYR]$/ ⚠️/' | less -RFX";
            cm = "commit -m";
            ca = "commit -am";
            dc = "diff --cached";
          };
        };
      }
      // (pkgs.sxm.git or { });
    }
  );
}
