# Official podman remote client for macOS, packaged from the upstream GitHub
# release binary rather than nixpkgs. nixpkgs' podman derivation set
# meta.platforms = lib.platforms.linux (refuses to evaluate on aarch64-darwin
# even though it still builds a darwin remote client), so we consume the
# prebuilt `podman-remote-release-darwin_arm64.zip` asset directly. The zip is
# fetched as a fixed-output derivation (fetchzip) and its adhoc-signed Mach-O
# binaries are installed verbatim.
{
  lib,
  stdenvNoCC,
  fetchzip,
  vfkit,
  gvproxy,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "podman";
  version = "6.0.0";

  # FOD: fetchzip strips the single `podman-6.0.0/` top-level dir, leaving
  # usr/ and docs/ at the source root.
  src = fetchzip {
    url = "https://github.com/containers/podman/releases/download/v${finalAttrs.version}/podman-remote-release-darwin_arm64.zip";
    hash = "sha256-Jf5RHa4IZ5cSwX6nKyDWEYfFfObHWsO+uqZ//fHarmg=";
  };

  # The binaries are adhoc (linker-signed) Mach-O and depend only on system
  # libraries (libSystem, libresolv, CoreFoundation, Security). Stripping or
  # re-signing would invalidate the signature and macOS would refuse to exec
  # them, so skip fixup entirely and install the bytes untouched.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    install -Dm555 usr/bin/podman           $out/bin/podman
    install -Dm555 usr/bin/podman-mac-helper $out/bin/podman-mac-helper

    for page in docs/*.1; do
      install -Dm444 "$page" "$out/share/man/man1/$(basename "$page")"
    done

    # Bundle the machine helpers podman drives for the applehv provider. On
    # darwin the compiled-in default helper_binaries_dir lists
    # "$BINDIR/../libexec/podman" first, where $BINDIR = dir of the invoked
    # podman binary (os.Executable(), which on darwin is NOT symlink-resolved).
    # Dropping vfkit + gvproxy here therefore lets `podman machine` locate them
    # with no containers.conf helper_binaries_dir override — both when podman is
    # run by its store path ($out/libexec/podman) and via the profile symlink
    # (/etc/profiles/per-user/<u>/libexec/podman), the latter requiring
    # environment.pathsToLink to include "/libexec" (see podman-desktop.nix).
    # Symlinks (not copies) keep the runtime deps clean and never touch the
    # helpers' own adhoc Mach-O signatures.
    mkdir -p $out/libexec/podman
    ln -s ${vfkit}/bin/vfkit     $out/libexec/podman/vfkit
    ln -s ${gvproxy}/bin/gvproxy $out/libexec/podman/gvproxy

    runHook postInstall
  '';

  meta = {
    description = "Official prebuilt podman remote client for macOS";
    homepage = "https://podman.io/";
    changelog = "https://github.com/containers/podman/blob/v${finalAttrs.version}/RELEASE_NOTES.md";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "podman";
    platforms = [ "aarch64-darwin" ];
    maintainers = [ { github = "kriswill"; } ];
  };
})
