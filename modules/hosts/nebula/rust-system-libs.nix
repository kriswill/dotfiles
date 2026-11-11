{
  # Fix nixpkgs' tectonic and codex builds, both pulled in by the ChatGPT app.
  # nixpkgs' rust hooks now tell the vendored -sys crates to link the system
  # libraries (AWS_LC_SYS_USE_SYSTEM and friends), and each package has to list
  # those libraries as inputs. These two didn't yet at the flake's pin, so
  # aws-lc-sys' build script panics. Fixed upstream right after it
  # (NixOS/nixpkgs 743696b7 for tectonic, 16b46369 for codex) by adding the
  # inputs below; this does the same until the flake's nixpkgs has them.
  #
  # A package that already lists aws-lc is left alone. Once both do, a warning
  # on every evaluation, nrs and CI alike, says to delete this file.
  configurations.nixos.nebula.module =
    { pkgs, lib, ... }:
    let
      missing = final: {
        tectonic-unwrapped = [ final.aws-lc ];
        codex = [
          final.aws-lc
          final.oniguruma
          final.sqlite
          final.zstd
        ];
      };
    in
    {
      nixpkgs.overlays = [
        (
          final: prev:
          lib.mapAttrs (
            name: inputs:
            if lib.any (p: lib.getName p == "aws-lc") prev.${name}.buildInputs then
              prev.${name}
            else
              prev.${name}.overrideAttrs (old: {
                buildInputs = old.buildInputs ++ inputs;
                passthru = old.passthru // {
                  systemLibsOverride = true;
                };
              })
          ) (missing final)
        )
      ];
      warnings =
        lib.optional
          (!lib.any (name: pkgs.${name}.systemLibsOverride or false) (lib.attrNames (missing pkgs)))
          "nixpkgs' tectonic and codex now list their system libraries themselves, so the overrides are switched off. Delete modules/hosts/nebula/rust-system-libs.nix.";
    };
}
