# Ours: redistribute the official signed bundle byte-for-byte. No re-signing,
# stripping, Mach-O rewriting, or source build: TCC relies on this identity.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation {
  pname = "cua-driver-signed";
  # Ours: includes upstream PR #5690 enforcing per-app launch grants.
  version = "0.47.24";
  src = fetchurl {
    url = "https://github.com/trycua/cua/releases/download/cua-driver-rs-v0.47.24/cua-driver-rs-0.47.24-darwin-arm64.tar.gz";
    hash = "sha256-zKicO4AtLTmArfD41UAPNLm06ohuuFXnFiyAcdPNwPI=";
  };
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/bin"
    cp -R CuaDriver.app "$out/Applications/"
    ln -s ../Applications/CuaDriver.app/Contents/MacOS/cua-driver "$out/bin/cua-driver"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    /usr/bin/codesign --verify --deep --strict \
      -R '=anchor apple generic and identifier "com.trycua.driver" and certificate leaf[subject.OU] = "YCK386LBJ7"' \
      "$out/Applications/CuaDriver.app"
  '';
  meta = {
    description = "Official Developer ID signed CuaDriver app (signature preserved)";
    homepage = "https://github.com/trycua/cua";
    platforms = [ "aarch64-darwin" ];
    mainProgram = "cua-driver";
  };
}
