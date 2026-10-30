# Run the shared generator offline; generated assets are not tracked in git.
#
# Ours: the generator and assets come from hermesSrc (see packages.nix).
{
  lib,
  runCommand,
  venv,
  hermesSrc,
}:
let
  src = lib.fileset.toSource {
    root = hermesSrc;
    fileset = lib.fileset.unions [
      (hermesSrc + "/scripts/generate_icons.py")
      (lib.fileset.fileFilter (file: file.hasExt "svg") (hermesSrc + "/assets"))
      # The DMG volume icon is hand-made raster artwork, not rendered from the svgs.
      (hermesSrc + "/assets/dmg-volume.png")
    ];
  };
in
runCommand "hermes-icons" { nativeBuildInputs = [ venv ]; } ''
  python ${src}/scripts/generate_icons.py --source ${src} --out $out
  python ${src}/scripts/generate_icons.py --source ${src} --out $out --check
''
