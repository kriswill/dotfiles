# Kanagawa "kris" — the personal flavor. NOT a canonical kanagawa.nvim variant:
# wave editor + wave syntax, but a dragon-family UI chrome (with a couple of
# deliberate cross-family picks, e.g. sumiInk0 for the status bar). Written as
# explicit literals rather than via ./mk.nix so it reproduces the long-standing
# flavor byte-for-byte; the canonical flavors recolor the same yazi layout.
{ palette }:
let
  p = palette;
in
{
  editor = {
    background = p.sumiInk3;
    foreground = p.fujiWhite;
    caret = p.oldWhite;
    invisibles = p.sumiInk6;
    lineHighlight = p.waveBlue2;
    selection = p.waveBlue2;
    findHighlight = p.waveBlue2;
    selectionBorder = p.dragonBlack2; # closest palette match to #222218
    gutterForeground = p.sumiInk6;
  };

  # wave syn table (matches the user's neovim treesitter highlighting).
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
    variable = p.fujiWhite;
  };

  diff = {
    add = p.winterGreen;
    delete = p.winterRed;
    change = p.winterBlue;
  };

  chrome = {
    fg = p.dragonWhite;
    on_accent = p.dragonBlack3;
    bg_deep = p.dragonBlack0;
    status_bg = p.sumiInk0;
    accent = p.dragonBlue2;
    green = p.dragonGreen2;
    red = p.waveRed;
    pink = p.dragonPink;
    yellow = p.carpYellow;
    blue = p.springBlue;
    border = p.dragonAqua;
    teal = p.waveAqua2;
    peach = p.peachRed;
    docs = p.waveAqua1;
    gray = p.dragonGray;
    faint = p.sumiInk6;
    orphan = p.dragonRed;
    exec = p.autumnGreen;
  };
}
