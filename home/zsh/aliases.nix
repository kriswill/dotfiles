{ pkgs }:

with pkgs;
let
  inherit (lib) getExe;
  dotfiles = "${home.homeDirectory}/src/github/kriswill/dotfiles";
in
{
  "..." = "../..";
  "...." = "../../..";
  # file listing
  ls = "${getExe eza} --icons";
  ld = "l -D";
  ll = "l -lhF";
  la = "l -a";
  t = "l -T -L3";
  l = "ls -lhF --git -I '.git|.DS_'";
  cat = "${getExe bat}";

  # system related
  ff = "${getExe fastfetch}";
  nrs = "${getExe nh} os switch ${dotfiles}";
  # hms = "${getExe nh} home switch ${dotfiles}";

  # git related
  g = "${getExe git}";
  gco = "g checkout";
  gba = "g branch -a";
  lg = "${getExe lazygit}";
  man = "${getExe bat-extras.batman}";
}
