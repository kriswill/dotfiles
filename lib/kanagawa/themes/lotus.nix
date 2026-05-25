# Canonical Kanagawa "lotus" (LIGHT) — transcribed from kanagawa.nvim
# lua/kanagawa/themes.lua (lotus). Light background; the shared mapper reads
# bg/fg from ui so the tmTheme inverts correctly.
{ palette }:
let
  p = palette;
in
import ./mk.nix {
  ui = {
    fg = p.lotusInk1;
    fg_dim = p.lotusInk2;
    nontext = p.lotusViolet1;
    bg = p.lotusWhite3;
    bg_m1 = p.lotusWhite2;
    bg_m3 = p.lotusWhite0;
    bg_search = p.lotusBlue2;
  };
  syn = {
    string = p.lotusGreen;
    number = p.lotusPink;
    constant = p.lotusOrange;
    identifier = p.lotusYellow;
    parameter = p.lotusBlue5;
    fun = p.lotusBlue4;
    keyword = p.lotusViolet4;
    operator = p.lotusYellow2;
    type = p.lotusAqua;
    regex = p.lotusYellow2;
    deprecated = p.lotusGray3;
    comment = p.lotusGray3;
    punct = p.lotusTeal1;
    special1 = p.lotusTeal2;
    special2 = p.lotusRed;
    special3 = p.lotusRed;
  };
  vcs = {
    added = p.lotusGreen2;
    removed = p.lotusRed2;
    changed = p.lotusYellow3;
  };
  diff = {
    add = p.lotusGreen3;
    delete = p.lotusRed4;
    change = p.lotusCyan;
  };
  diag.hint = p.lotusAqua2;
}
