{ pkgs }:

with pkgs;
let
  inherit (lib) getExe;
in
{
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
  nrs = "${getExe nh} os switch $HOME/src/github/kriswill/dotfiles";
  hms = "${getExe nh} home switch $HOME/src/github/kriswill/dotfiles";

  # git related
  g = "${getExe git}";
  gco = "g checkout";
  gba = "g branch -a";
  lg = "${getExe lazygit}";
}