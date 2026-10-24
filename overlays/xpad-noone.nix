# TEMPORARY — nixpkgs now signs every out-of-tree kernel module with kmodigest
# during `make modules_install`, and the module aggregator (kmod/aggregator.nix)
# cats a `<module>.ko.cer` for each external module into modules.cer. xpad-noone
# (pulled in by hardware.xone ← snowglobe's gaming profile) installed its .ko with
# a plain `install`, so it never got signed, no .cer existed, and
# linux-<ver>-modules failed with
#   cat: kernel/drivers/xpad-noone/xpad-noone.ko.cer: No such file or directory
#
# Backport of NixOS/nixpkgs#576469 (merged to master 2026-10-22 as ffcd595):
# install through the kernel's modules_install so kmodigest runs. DELETE this
# overlay (and its modules/overlays.nix line) once our nixos-unstable lock
# contains that commit.
_final: prev: {
  kernelPackagesExtensions = prev.kernelPackagesExtensions ++ [
    (_kfinal: kprev: {
      xpad-noone = kprev.xpad-noone.overrideAttrs (old: {
        makeFlags = old.makeFlags ++ [
          "KERNEL_SRC=${kprev.kernel.dev}/lib/modules/${kprev.kernel.modDirVersion}/build"
          "INSTALL_MOD_PATH=${placeholder "out"}"
          "INSTALL_MOD_DIR=kernel/drivers/xpad-noone"
        ];
        # null falls back to stdenv's default installPhase (make $installTargets).
        installPhase = null;
        installTargets = [ "modules_install" ];
        installFlags = [
          "-C"
          "${kprev.kernel.dev}/lib/modules/${kprev.kernel.modDirVersion}/build"
          "M=$(PWD)"
        ];
        strictDeps = true;
        __structuredAttrs = true;
      });
    })
  ];
}
