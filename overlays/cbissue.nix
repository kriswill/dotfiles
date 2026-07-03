# cbissue — open Codeberg (Forgejo) issues from the CLI; token via 1Password.
# See pkgs/cbissue.nix.
_final: prev: {
  cbissue = prev.callPackage ../pkgs/cbissue.nix { };
}
