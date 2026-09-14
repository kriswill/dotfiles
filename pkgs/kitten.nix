{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation rec {
  pname = "kitten";
  version = "0.48.2";

  src =
    fetchurl
      {
        aarch64-darwin = {
          url = "https://github.com/kovidgoyal/kitty/releases/download/v${version}/kitten-darwin-arm64";
          hash = "sha256-l5Y+OIUBLj2PpxHPwyAdszgAAuuZJ/Iw87CEAPGux/A=";
        };
        x86_64-linux = {
          url = "https://github.com/kovidgoyal/kitty/releases/download/v${version}/kitten-linux-amd64";
          hash = "sha256-KfH8I1P/zIgLkLxKQZnxh8rvG2CNp4COSl9GQE6HWZE=";
        };
      }
      .${stdenv.hostPlatform.system};

  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    install -D $src $out/bin/kitten
    runHook postInstall
  '';

  meta = with lib; {
    description = "Kitten - A collection of small, useful programs for the kitty terminal";
    homepage = "https://github.com/kovidgoyal/kitty";
    license = licenses.gpl3Only;
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
    maintainers = [ ];
    mainProgram = "kitten";
  };
}
