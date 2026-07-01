# Replace nixpkgs' podman (Linux-only meta.platforms on darwin) with the
# official prebuilt macOS remote client. See pkgs/podman.nix.
_final: prev: {
  podman = prev.callPackage ../pkgs/podman.nix { };
}
