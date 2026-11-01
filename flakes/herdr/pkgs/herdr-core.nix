# herdr-core (`hc`): upstream's release build, unchanged — no fixup at all.
# On Linux it is a static-pie binary, so it needs no patching, and
# `hc machine add` can copy it to another machine as-is (a source-built,
# nix-linked hc can't; nixpkgs#581031 has to download upstream's build for
# that). On macOS it is upstream's signed Mach-O, which any fixup (strip,
# install_name_tool) would invalidate. Version and hashes: ../sources.json,
# refreshed by ../update.ts.
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
    install -Dm755 herdr-core $out/bin/herdr-core
    # The installer adds `hc` only when no other `hc` exists (some window
    # managers ship one); a package can always have it.
    ln -s herdr-core $out/bin/hc
    install -Dm644 LICENSE THIRD-PARTY-NOTICES -t $out/share/licenses/herdr-core
    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgram = "${placeholder "out"}/bin/hc";
  doInstallCheck = true;

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
