{ stdenvNoCC, lib, fetchzip, }:
let uuid = "tilingshell@ferrarodomenico.com";
in stdenvNoCC.mkDerivation rec {
  pname = "tilingshell";
  version = "11.0.0";

  src = fetchzip {
    url =
      "https://github.com/domferr/tilingshell/releases/download/${version}/${uuid}.zip";
    hash = "sha256-7ocvXad8VVl8ePuD918PXLOiGuxEBwxpyVD3RuBnAtM=";
    stripRoot = false;
  };

  installPhase = ''
    mkdir -p "$out/share/gnome-shell/extensions/${uuid}"
    cp -r * "$out/share/gnome-shell/extensions/${uuid}/"
  '';

  passthru = {
    extensionUuid = uuid;
    extensionPortalSlug = pname;
  };

  meta = with lib; {
    description = "Extend Gnome Shell with advanced tiling window management.";
    license = licenses.gpl2;
    homepage = "https://github.com/domferr/tilingshell";
    platforms = platforms.linux;
  };
}
