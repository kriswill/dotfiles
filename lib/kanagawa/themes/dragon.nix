# Canonical Kanagawa "dragon" — transcribed from kanagawa.nvim
# lua/kanagawa/themes.lua (dragon).
{ palette }:
let
  p = palette;
in
import ./mk.nix {
  ui = {
    fg = p.dragonWhite;
    fg_dim = p.oldWhite;
    nontext = p.dragonBlack6;
    bg = p.dragonBlack3;
    bg_m1 = p.dragonBlack2;
    bg_m3 = p.dragonBlack0;
    bg_search = p.waveBlue2;
  };
  syn = {
    string = p.dragonGreen2;
    number = p.dragonPink;
    constant = p.dragonOrange;
    identifier = p.dragonYellow;
    parameter = p.dragonGray;
    fun = p.dragonBlue2;
    keyword = p.dragonViolet;
    operator = p.dragonRed;
    type = p.dragonAqua;
    regex = p.dragonRed;
    deprecated = p.katanaGray;
    comment = p.dragonAsh;
    punct = p.dragonGray2;
    special1 = p.dragonTeal;
    special2 = p.dragonRed;
    special3 = p.dragonRed;
  };
  vcs = {
    added = p.autumnGreen;
    removed = p.autumnRed;
    changed = p.autumnYellow;
  };
  diff = {
    add = p.winterGreen;
    delete = p.winterRed;
    change = p.winterBlue;
  };
  diag.hint = p.waveAqua1;
}
