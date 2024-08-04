{ pkgs }:

with pkgs;
let inherit (lib) getExe;
in {
  ".." = "cd ..";
  cat = "${getExe bat}";

  # git related
  g = "${getExe git}";
  gco = "g checkout";
  gba = "g branch -a";
}
