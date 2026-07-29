# TEMPORARY — nixpkgs bumped libdisplay-info to 0.4.0 (3927e90c, 2026-07-25),
# but lact 0.9.1's vendored libdisplay-info-sys 0.3.0 requires `< 0.4.0`, so
# its build.rs pkg-config probe panics. Upstream's fix builds lact against a
# new libdisplay-info_0_3 attr (master 3ee083c2, 2026-07-27); that attr — and
# the generic-ised derivation behind it — postdate our nixos-unstable rev, so
# reproduce the same 0.3.0 here (version + hash lifted from upstream's
# pkgs/by-name/li/libdisplay-info/0.3.nix).
# DELETE this overlay (and its modules/overlays.nix line) once a flake.lock
# bump carries 3ee083c2.
final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  lact = prev.lact.override {
    libdisplay-info = prev.libdisplay-info.overrideAttrs {
      version = "0.3.0";
      src = final.fetchFromGitLab {
        domain = "gitlab.freedesktop.org";
        owner = "emersion";
        repo = "libdisplay-info";
        rev = "0.3.0";
        hash = "sha256-nXf2KGovNKvcchlHlzKBkAOeySMJXgxMpbi5z9gLrdc=";
      };
    };
  };
}
