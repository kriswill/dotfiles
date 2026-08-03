{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation rec {
  pname = "kitten";
  version = "0.42.2";

  src =
    fetchurl
      {
        aarch64-darwin = {
          url = "https://github.com/kovidgoyal/kitty/releases/download/v${version}/kitten-darwin-arm64";
          hash = "sha256-quDlS0S3U/z8lcNfkBWlBwmDrv8DBKxmLSrhIOhpSxk=";
        };
        x86_64-linux = {
          url = "https://github.com/kovidgoyal/kitty/releases/download/v${version}/kitten-linux-amd64";
          hash = "sha256-BE2wPrBpx2VauFdUP7lUFirrafkg0R/E+k/knDfvMIM=";
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
