# On darwin, replace nixpkgs' podman (Linux-only meta.platforms) with the
# official prebuilt macOS remote client (pkgs/podman.nix). On Linux, nixpkgs'
# own podman is the right one — pass it through untouched, since every host
# (both OSes) applies the whole flake.overlays set.
_final: prev: {
  podman = if prev.stdenv.isDarwin then prev.callPackage ../pkgs/podman.nix { } else prev.podman;
}
