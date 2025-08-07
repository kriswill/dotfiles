{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation rec {
  pname = "kitten";
  version = "0.42.2";

  src = fetchurl {
    url = "https://github.com/kovidgoyal/kitty/releases/download/v${version}/kitten-darwin-arm64";
    hash = "sha256-quDlS0S3U/z8lcNfkBWlBwmDrv8DBKxmLSrhIOhpSxk=";
  };

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
    platforms = [ "aarch64-darwin" ];
    maintainers = [ ];
    mainProgram = "kitten";
  };
}
