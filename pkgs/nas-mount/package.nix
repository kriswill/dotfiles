# Compiled (not shell-scripted) mount helper for the UNAS Pro 4 SMB share —
# see main.rs for why it's a Mach-O binary rather than a script. No external
# crates (pure std), so a bare rustc invocation rather than
# rustPlatform.buildRustPackage's Cargo.lock machinery.
{ stdenv, rustc }:
stdenv.mkDerivation {
  pname = "nas-mount";
  version = "0.1.0";
  dontUnpack = true;
  nativeBuildInputs = [ rustc ];

  buildPhase = ''
    runHook preBuild
    rustc -O -o nas-mount ${./main.rs}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp nas-mount $out/bin/nas-mount
    runHook postInstall
  '';

  meta = {
    description = "Mounts the UNAS Pro 4 Personal-Drive SMB share if not already mounted";
    mainProgram = "nas-mount";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
  };
}
