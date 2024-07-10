{ pkgs, ... }:

pkgs.stdenvNoCC.mkDerivation rec {
    pname = "sddm-eucalyptus-drop";
    version = "2.0.0";
    dontBuild = true;
    dontWrapQtApps = true;
    buildInputs = with pkgs.qt5; [
      qtbase qtquickcontrols qtgraphicaleffects
    ];
    src = pkgs.fetchzip {
      url = "https://gitlab.com/api/v4/projects/37107648/packages/generic/sddm-eucalyptus-drop/${version}/sddm-eucalyptus-drop-v${version}.zip";
      hash = "sha256-BNLh+U2vq17PTf+i5nE2criLG5J94Nxj1+2dZ63GHf4=";
    };
    installPhase = ''
      mkdir -p $out/share/sddm/themes
      cp -aR $src $out/share/sddm/themes/eucalyptus-drop
    '';
    meta = with pkgs.lib; {
      description = "Eucalyptus Drop is an enhanced fork of SDDM Sugar Candy by Marian Arlt.";
      homepage = "https://gitlab.com/Matt.Jolly/sddm-eucalyptus-drop";
      license = licenses.gpl3;
      platforms = platforms.linux;
    };
  }