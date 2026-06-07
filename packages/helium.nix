# Helium browser, packaged from the upstream AppImage (imputnet/helium-linux).
# Bump `version`/`hash` together; get the hash with:
#   nix store prefetch-file --hash-type sha256 \
#     https://github.com/imputnet/helium-linux/releases/download/<version>/helium-<version>-x86_64.AppImage
{
  appimageTools,
  fetchurl,
}:
let
  pname = "helium";
  version = "0.12.5.1";
  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    hash = "sha256-uUZauNralX6katmnO9VDLEs+d+HIhkjkeV36Dw2eUmM=";
  };
  # Pull the upstream .desktop entry and icon out of the AppImage so the
  # browser shows up in the desktop launcher, not just on the terminal.
  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # The shipped helium.desktop already uses `Exec=helium %U` / `Icon=helium`,
  # which match the wrapper binary name (pname), so no rewriting is needed.
  extraInstallCommands = ''
    install -Dm644 ${appimageContents}/helium.desktop \
      $out/share/applications/helium.desktop
    cp -r ${appimageContents}/usr/share/icons $out/share/
  '';
}
