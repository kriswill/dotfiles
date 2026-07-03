# helium-config — snapshot/restore Helium's allowlisted profile files into
# config/helium/ (age-encrypted), without symlinking the live profile.
# See pkgs/helium-config.nix and config/README.md.
_final: prev: {
  helium-config = prev.callPackage ../pkgs/helium-config.nix { };
}
