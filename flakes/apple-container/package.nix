{
  lib,
  stdenv,
  fetchurl,
  xar,
  cpio,
  makeWrapper,
}:

let
  version = "1.0.0";
  hash = "sha256-E/RfJtqUw1Sty+/h6PdjHn8SbpPF1N1qWlOKpmtPR50=";
in

# Apple ships `container` as a flat, signed `.pkg`; we install the already-signed
# Mach-O binaries instead of building the Swift source, and `dontFixup` keeps Apple's
# code signature and entitlements intact. Full rationale: README.md ("How it works").
stdenv.mkDerivation {
  pname = "apple-container";
  inherit version;

  src = fetchurl {
    url = "https://github.com/apple/container/releases/download/${version}/container-${version}-installer-signed.pkg";
    inherit hash;
  };

  nativeBuildInputs = [
    xar
    cpio
    makeWrapper
  ];

  dontConfigure = true;
  dontBuild = true;

  # Crack the flat .pkg: xar yields a top-level Payload, which is a gzip'd cpio archive
  # extracting to ./bin and ./libexec.
  unpackPhase = ''
    xar -xf $src
    gunzip -dc Payload | cpio -i
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/libexec
    mv bin/container bin/container-apiserver $out/bin/
    mv libexec/container $out/libexec/

    # `container` loads plugins from <install-root>/libexec, where install-root is
    # derived from its own, non-symlink-resolved executable path — exec'd via the Nix
    # profile it would find no plugins. The wrapper makes the CLI exec from $out.
    # Full rationale: README.md ("Why `container` is wrapped").
    mv $out/bin/container $out/bin/.container-wrapped
    makeWrapper $out/bin/.container-wrapped $out/bin/container

    runHook postInstall
  '';

  # Apple-signed binaries — strip/fixup would break the code signature. (The wrapper
  # above runs in installPhase, before fixup, and only execs the untouched binary.)
  dontFixup = true;

  meta = {
    description = "Apple's native container runtime for macOS";
    homepage = "https://github.com/apple/container";
    license = lib.licenses.asl20;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "container";
  };
}
