# herdr-core (`hc`): upstream's release build, unchanged — no fixup at all.
# On Linux it is a static-pie binary, so it needs no patching, and
# `hc machine add` can copy it to another machine as-is (a source-built,
# nix-linked hc can't; nixpkgs#581031 has to download upstream's build for
# that). Version and hashes: ../sources.json, refreshed by ../update.ts.
#
# On macOS (core >= 0.1.18) it is upstream's Developer ID-signed
# `Herdr Core.app` (dev.herdr.core), copied whole into libexec/ (not
# Applications/: it is an LSUIElement helper with no use from Finder or
# Spotlight). bin/herdr-core and bin/hc link into the bundle. The core and
# its holders disclaim privacy responsibility, so macOS asks on behalf of the
# core's own executable, and only one inside the bundle carries the usage
# descriptions (local network, microphone, …) that let terminal programs
# reach the LAN or the mic. The tarball's bare `herdr-core` beside the bundle
# (for older updaters) is skipped. Every path into it resolves to the bundle:
# upstream canonicalizes its own path to find the bundle (`hc machine add`
# packs the whole bundle) and the nix store (`hc update` refusal). TCC grants
# key on the signature, not the path, so they survive version bumps.
#
# Installed under /nix/store, hc counts itself managed by nix: `hc update`
# refuses ("update it in your Nix configuration") and the app never offers
# to replace it.
{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}:
let
  source = (lib.importJSON ../sources.json).herdr-core;
  inherit (stdenvNoCC.hostPlatform) system;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-core";
  inherit (source) version;

  src = fetchurl {
    inherit (source.targets.${system} or (throw "herdr-core: no release build for ${system}")) url hash;
  };
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
  ''
  + (
    if stdenvNoCC.hostPlatform.isDarwin then
      ''
        mkdir -p $out/libexec $out/bin
        cp -R "Herdr Core.app" $out/libexec/
        ln -s "../libexec/Herdr Core.app/Contents/MacOS/herdr-core" $out/bin/herdr-core
      ''
    else
      ''
        install -Dm755 herdr-core $out/bin/herdr-core
      ''
  )
  + ''
    # The installer adds `hc` only when no other `hc` exists (some window
    # managers ship one); a package can always have it.
    ln -s herdr-core $out/bin/hc
    install -Dm644 LICENSE THIRD-PARTY-NOTICES -t $out/share/licenses/herdr-core
    runHook postInstall
  '';

  # On macOS the bundle's executable is never run at build time: executing a
  # signed .app makes macOS stamp it with com.apple.macl, an xattr the nix
  # daemon may not strip (App Management protection), and the output then
  # fails to register ("clearing flags of path …: Operation not permitted").
  # The version is read from the bundle's Info.plist instead.
  nativeInstallCheckInputs = lib.optional (!stdenvNoCC.hostPlatform.isDarwin) versionCheckHook;
  versionCheckProgram = "${placeholder "out"}/bin/hc";
  doInstallCheck = true;
  # The copy must still carry upstream's signature (skipped where codesign
  # isn't reachable, as in a sandboxed build).
  preInstallCheck = lib.optionalString stdenvNoCC.hostPlatform.isDarwin ''
    plist="$out/libexec/Herdr Core.app/Contents/Info.plist"
    grep -q "<key>CFBundleShortVersionString</key><string>${finalAttrs.version}</string>" "$plist" \
      || { echo "Herdr Core.app is not version ${finalAttrs.version}" >&2; exit 1; }
    if [ -x /usr/bin/codesign ]; then
      /usr/bin/codesign --verify --deep --strict "$out/libexec/Herdr Core.app"
    fi
  '';

  meta = {
    description = "Terminals for coding agents that keep running after you leave (hc)";
    homepage = "https://herdr.dev/core";
    changelog = "https://github.com/herdrdev/herdr-core/blob/v${finalAttrs.version}/CHANGELOG.md";
    # THIRD-PARTY-NOTICES lists the bundled crates' licenses.
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "hc";
    platforms = builtins.attrNames source.targets;
  };
})
