# create custom derivations using pkgs.callPackage
{ pkgs, ... }:
{
  # my-package = pkgs.callPackage ./my-package.nix { };
  helium = pkgs.callPackage ./helium.nix { };
  dots-adopt = pkgs.callPackage ./dots-adopt.nix { };
  wowup = pkgs.callPackage ./wowup.nix {
    # WoW lives inside the Steam/Proton prefix shared with Battle.net (compatdata
    # 3082075026). Point this at the dir containing `_retail_`; change it here if
    # the install moves. Set to null to wire nothing and add WoW in the GUI.
    wowPath = "/home/k/.local/share/Steam/steamapps/compatdata/3082075026/pfx/drive_c/Program Files (x86)/World of Warcraft";
  };
}
