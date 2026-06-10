{
  lib,
  stdenv,
  fetchurl,
  xar,
  cpio,
  gzip,
  makeWrapper,
  version ? "1.0.0",
  hash ? "sha256-E/RfJtqUw1Sty+/h6PdjHn8SbpPF1N1qWlOKpmtPR50=",
}:

# Apple ships `container` as a flat, signed `.pkg`. We extract the already-signed
# Mach-O binaries rather than building the Swift source — the source build needs the
# macOS SDK plus Virtualization entitlements and re-signing, none of which Nix can do
# cleanly. `dontFixup` keeps Apple's code signature (and its entitlements) intact.
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
    gzip
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
    cp -a bin/container bin/container-apiserver $out/bin/
    cp -a libexec/container $out/libexec/

    # `container` finds its plugins under <install-root>/libexec/container/plugins,
    # where install-root = grandparent of its OWN executable path. Per upstream
    # InstallRoot.swift that path is _NSGetExecutablePath WITHOUT symlink resolution,
    # so when invoked via the Nix profile (~/.../bin/container) the install-root
    # resolves to the profile dir — which links bin/ but NOT libexec/ — and
    # `container system start` dies with "cannot find any plugins". Wrapping makes the
    # CLI exec from $out, so install-root = $out (which has libexec/). The install root
    # is read-only (plugins are only ever read); all writable state lives under
    # CONTAINER_APP_ROOT (~/Library/Application Support/com.apple.container).
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
