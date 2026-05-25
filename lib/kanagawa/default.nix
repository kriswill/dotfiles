# Kanagawa palette + per-flavor semantic theme tables.
#
# `lib.kanagawa` spreads the raw name→hex palette at the top level (so existing
# consumers like `lib.kanagawa.sumiInk3` and `nix eval --file palette.nix` keep
# working) and adds `lib.kanagawa.themes.<flavor>` — the editor/syn/diff/chrome
# role tables consumed by pkgs/yazi-kanagawa-flavor. See themes/mk.nix.
let
  palette = import ./palette.nix;
  theme = name: import (./themes + "/${name}.nix") { inherit palette; };
in
palette
// {
  themes = {
    wave = theme "wave";
    dragon = theme "dragon";
    lotus = theme "lotus";
    kris = theme "kris";
  };
}
