{ pkgs,
  background-image ? pkgs.wallpapers.yoda-dagoba-2,
  ... }:

pkgs.stdenvNoCC.mkDerivation rec {
  pname = "sddm-eucalyptus-drop";
  version = "2.0.0";
  dontBuild = true;
  dontWrapQtApps = true;
  buildInputs = with pkgs.qt5; [
    qtbase
    qtquickcontrols
    qtgraphicaleffects
  ];
  src = pkgs.fetchFromGitLab {
    owner = "Matt.Jolly";
    repo = "sddm-eucalyptus-drop";
    rev = "v2.0.0";
    sha256 = "wq6V3UOHteT6CsHyc7+KqclRMgyDXjajcQrX/y+rkA0=";
  };
  installPhase = ''
    runHook preInstall
    THEME_DIR=$out/share/sddm/themes/eucalyptus-drop
    mkdir -p $THEME_DIR
    cp -r * $THEME_DIR
    cat theme.conf | sed "s|Background=.*|background=\"${background-image}\"|g" > $THEME_DIR/theme.conf
    runHook postInstall
  '';
  meta = with pkgs.lib; {
    description = "Eucalyptus Drop is an enhanced fork of SDDM Sugar Candy by Marian Arlt.";
    homepage = "https://gitlab.com/Matt.Jolly/sddm-eucalyptus-drop";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
