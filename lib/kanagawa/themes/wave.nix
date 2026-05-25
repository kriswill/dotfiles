# Canonical Kanagawa "wave" — transcribed from kanagawa.nvim
# lua/kanagawa/themes.lua (wave). Only the roles the yazi builder consumes are
# included; the shared mapper (./mk.nix) turns them into editor/syn/diff/chrome.
{ palette }:
let
  p = palette;
in
import ./mk.nix {
  ui = {
    fg = p.fujiWhite;
    fg_dim = p.oldWhite;
    nontext = p.sumiInk6;
    bg = p.sumiInk3;
    bg_m1 = p.sumiInk2;
    bg_m3 = p.sumiInk0;
    bg_search = p.waveBlue2;
  };
  syn = {
    string = p.springGreen;
    number = p.sakuraPink;
    constant = p.surimiOrange;
    identifier = p.carpYellow;
    parameter = p.oniViolet2;
    fun = p.crystalBlue;
    keyword = p.oniViolet;
    operator = p.boatYellow2;
    type = p.waveAqua2;
    regex = p.boatYellow2;
    deprecated = p.katanaGray;
    comment = p.fujiGray;
    punct = p.springViolet2;
    special1 = p.springBlue;
    special2 = p.waveRed;
    special3 = p.peachRed;
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
