# noctalia-config — snapshot/restore Noctalia's settings.toml into
# config/noctalia/ without symlinking the live file. See pkgs/noctalia-config.nix.
_final: prev: {
  noctalia-config = prev.callPackage ../pkgs/noctalia-config.nix { };
}
