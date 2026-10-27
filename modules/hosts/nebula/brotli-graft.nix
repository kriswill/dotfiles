{ inputs, ... }:
{
  # Swap brotli 1.2.1 into nebula's system in place of 1.2.0, without
  # rebuilding what depends on it. CVE-2026-111497 ("Node2Shell") is an
  # out-of-bounds write in the decoder, fixed in 1.2.1 (2026-10-21), and
  # curl, libsoup, Qt, Node, aiohttp, Wireshark and freetype all decode
  # untrusted brotli with it. nixpkgs has 1.2.1 on staging only, and brotli
  # sits under 633 of the system's ~3000 store paths (Chromium, Electron, GIMP,
  # …), so a plain override would recompile all of them.
  #
  # replaceDependencies builds just the replacements (seconds), then copies
  # every dependent path and rewrites its references to the new store paths
  # (names are the same length, 1.2.0 → 1.2.1). It costs disk (~12.6 GiB of
  # rewritten copies) and import-from-derivation at eval time, not compiles.
  # The Python module links the system library (USE_SYSTEM_BROTLI), so it's
  # rebuilt against 1.2.1 only to drop the 1.2.0 name. Determinate Nix already
  # carries its own 1.2.1.
  #
  # Once nixpkgs ships 1.2.1 the replacement list goes empty (no swap, no
  # import-from-derivation) and a warning on every evaluation, nrs and CI
  # alike, says to delete this file. knowledge/decisions/brotli-graft.md
  configurations.nixos.nebula.module =
    { pkgs, lib, ... }:
    let
      fixedVersion = "1.2.1";
      needed = lib.versionOlder pkgs.brotli.version fixedVersion;
      bump =
        brotli:
        brotli.overrideAttrs (old: {
          version = fixedVersion;
          src = old.src.override {
            tag = "v${fixedVersion}";
            hash = "sha256-llY72cYffDv0ugsH0p89xIPEbElV4L8u7U/Fe8hT3gI=";
          };
        });
      brotli = bump pkgs.brotli;
      brotli32 = bump pkgs.pkgsi686Linux.brotli;
      swap = old: new: {
        oldDependency = old;
        newDependency = new;
      };
    in
    {
      # Stock replaceDependencies left gimp (and the 153 paths under it) on
      # 1.2.0: gimptool holds a store path whose name half the compiler
      # garbled, so the hash-name rewrite missed it. And it rewrites a NAR
      # stream, so renaming sibling dirs named after store paths can unsort
      # it and fail the build, by chance of the new hashes. While the graft is
      # on, use the patched rewriter from the replace-dependencies sub-flake
      # (flakes/replace-dependencies), which fixes both and keeps package
      # identity for nixploit. The check picks the value, never the attribute
      # name: nixpkgs.overlays can't depend on pkgs, and an overlay's names
      # can't depend on prev, or evaluation recurses.
      nixpkgs.overlays = [
        (final: prev: {
          replaceDirectDependencies =
            if lib.versionOlder prev.brotli.version fixedVersion then
              (inputs.replace-dependencies.overlays.default final prev).replaceDirectDependencies
            else
              prev.replaceDirectDependencies;
        })
      ];
      system.replaceDependencies.replacements = lib.optionals needed [
        (swap pkgs.brotli.lib brotli.lib)
        (swap pkgs.brotli.out brotli.out)
        (swap pkgs.brotli.dev brotli.dev)
        (swap pkgs.pkgsi686Linux.brotli.lib brotli32.lib)
        (swap pkgs.python3Packages.brotli (pkgs.python3Packages.brotli.override { inherit brotli; }))
      ];
      warnings =
        lib.optional (!needed)
          "nixpkgs now ships brotli ${pkgs.brotli.version}, so the brotli ${fixedVersion} graft is switched off. Delete modules/hosts/nebula/brotli-graft.nix (see knowledge/decisions/brotli-graft.md).";
    };
}
