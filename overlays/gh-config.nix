# gh-config — snapshot/restore gh's config.yml into config/gh/ without
# symlinking the live file (gh's atomic-rename saves break stow links).
# See pkgs/gh-config.nix.
_final: prev: {
  gh-config = prev.callPackage ../pkgs/gh-config.nix { };
}
