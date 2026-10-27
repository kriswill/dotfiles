{
  # Build Gajim against Pillow 13.0.0 until nixpkgs ships it. Gajim decodes
  # images from the network with Pillow (received files, avatars, link
  # previews), and nixpkgs' 12.3.0 has 39 advisories fixed only in 13.0.0,
  # which nixpkgs has on staging so far (084270a). Gajim is the only runtime
  # user of Pillow on nebula, so overriding just its Python rebuilds three
  # derivations (pillow, qrcode, gajim) instead of everything that uses Pillow
  # while building.
  #
  # Once nixpkgs ships 13.0.0 this falls back to the stock Gajim and a warning
  # on every evaluation, nrs and CI alike, says to delete this file.
  # knowledge/decisions/gajim-pillow-13.md
  configurations.nixos.nebula.module =
    { pkgs, lib, ... }:
    let
      pillowVersion = "13.0.0";
      needed = lib.versionOlder pkgs.python3Packages.pillow.version pillowVersion;
      python3 = pkgs.python3.override {
        self = python3;
        packageOverrides = _pyFinal: pyPrev: {
          pillow = pyPrev.pillow.overridePythonAttrs (old: {
            version = pillowVersion;
            src = old.src.override {
              tag = pillowVersion;
              hash = "sha256-7FHwvgfT40qiHmvcJFZN/FlOECE0YiqOLBEYCMugk+4=";
            };
          });
        };
      };
    in
    {
      programs.gajim.package = lib.mkIf needed (pkgs.gajim.override { inherit python3; });
      warnings =
        lib.optional (!needed)
          "nixpkgs now ships pillow ${pkgs.python3Packages.pillow.version}, so the Gajim Pillow ${pillowVersion} override is switched off. Delete modules/hosts/nebula/gajim-pillow.nix (see knowledge/decisions/gajim-pillow-13.md).";
    };
}
