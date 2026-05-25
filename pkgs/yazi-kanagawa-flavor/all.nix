# Builds all four flavors from ./flavors.nix into an attrset keyed by flavor
# name (e.g. "kanagawa-wave" → derivation). Themes are read straight from
# lib/kanagawa so this works whether or not the caller's `lib` carries the
# `kanagawa` helper.
{ lib, pkgs }:
let
  specs = import ./flavors.nix;
  inherit ((import ../../lib/kanagawa)) themes;
in
lib.listToAttrs (
  map (
    s:
    lib.nameValuePair s.name (
      import ./. {
        inherit lib pkgs;
        inherit (s) name title uuid;
        appearance = s.appearance or "dark";
        theme = themes.${s.theme};
      }
    )
  ) specs
)
