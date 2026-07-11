# TEMPORARY — the pinned nixpkgs' cctools ld64 1010.6 crashes (SIGTRAP,
# "Trace/BPT trap: 5") linking some aarch64-darwin binaries; the real fix is
# on staging (NixOS/nixpkgs#536365). Until it — or the per-package master
# workarounds — reach nixos-unstable, replicate those workarounds here
# byte-identically so the drvs hash-match hydra's cache (no local builds):
#   kitty:    master 83cc719d53 (2026-07-09), plain -fuse-ld=lld
#   vfkit:    master 559ebc0633 (2026-07-09), absolute path to ld64.lld
#   starship: master 883e799eb2 (2026-07-10), plain -fuse-ld=lld
# DELETE this overlay (and its modules/overlays.nix line) once a flake.lock
# bump builds both without it. Linux passes through untouched (empty set).
final: prev:
let
  inherit (prev) lib stdenv;
  useLld =
    drv: linkFlag:
    drv.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.llvmPackages.lld ];
      env = (old.env or { }) // {
        NIX_CFLAGS_LINK = linkFlag;
      };
    });
in
lib.optionalAttrs stdenv.hostPlatform.isDarwin {
  kitty = useLld prev.kitty "-fuse-ld=lld";
  vfkit = useLld prev.vfkit "-fuse-ld=${lib.getExe' final.llvmPackages.lld "ld64.lld"}";
  starship = useLld prev.starship "-fuse-ld=lld";
}
