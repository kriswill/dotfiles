# wowup — WowUp-CF (WoW addon manager) from the upstream AppImage; Linux-only
# (appimage runtime). wowPath defaults inside pkgs/wowup.nix.
_final: prev: {
  wowup = prev.callPackage ../pkgs/wowup.nix { };
}
