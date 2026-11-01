# Herdr, the desktop app: upstream's release build (a GPUI/wgpu binary),
# patched to run from the Nix store and nothing else. ./herdr-app-wrap.nix adds the
# telemetry and settings choices on top. Version and hashes: ../sources.json,
# refreshed by ../update.ts.
#
# No wrapper here, and no LD_LIBRARY_PATH or PATH anywhere: the app passes its
# environment to herdr-core, which passes it to every terminal it starts, so
# anything set here would leak into every shell. The libraries it dlopens go
# on its RUNPATH instead.
#
# The self-updater stays off: it only arms when herdr-app.svg sits beside the
# running binary (upstream src/update.rs `find_root`), so the icon goes to
# share/icons and installCheck makes sure of it. With no install folder to
# replace, the app also skips its own update checks; a nix-store herdr-core
# is "managed" and never offered an update either.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  libGL,
  libxcb,
  libxkbcommon,
  vulkan-loader,
  wayland,
  versionCheckHook,
}:
let
  source = (lib.importJSON ../sources.json).herdr-app;
  inherit (stdenv.hostPlatform) system;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "herdr-app-unwrapped";
  inherit (source) version;

  src = fetchurl {
    inherit (source.targets.${system} or (throw "herdr-app: no release build for ${system}")) url hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
  ];
  # DT_NEEDED: libc/libm (glibc), libgcc_s, xcb and xkbcommon.
  buildInputs = [
    libxcb
    libxkbcommon
    (lib.getLib stdenv.cc.cc)
  ];
  # dlopened, so autoPatchelf adds them to the RUNPATH: Vulkan (wgpu's
  # renderer), Wayland and EGL (the GL fallback).
  runtimeDependencies = [
    vulkan-loader
    wayland
    libGL
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 herdr-app $out/libexec/herdr-app/herdr-app
    mkdir -p $out/bin
    ln -s ../libexec/herdr-app/herdr-app $out/bin/herdr-app
    install -Dm644 herdr-app.svg $out/share/icons/hicolor/scalable/apps/herdr-app.svg
    install -Dm644 LICENSE THIRD-PARTY-NOTICES -t $out/share/licenses/herdr-app
    runHook postInstall
  '';

  # The installer's launcher entry. A bare Exec resolves on PATH, so a system
  # that installs the wrapped package launches the wrapper.
  desktopItems = [
    (makeDesktopItem {
      name = "herdr-app";
      desktopName = "Herdr";
      comment = "Terminals and coding agents that keep running";
      exec = "herdr-app";
      icon = "herdr-app";
      terminal = false;
      categories = [ "Development" ];
      startupWMClass = "herdr-app";
    })
  ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgram = "${placeholder "out"}/bin/herdr-app";
  doInstallCheck = true;
  preInstallCheck = ''
    if [ -e $out/libexec/herdr-app/herdr-app.svg ]; then
      echo "herdr-app.svg beside the binary would arm the self-updater" >&2
      exit 1
    fi
  '';

  # The oldest herdr-core this release accepts (its manifest's core_min); the
  # NixOS module warns when the configured core is older.
  passthru.coreMin = source.coreMin or null;

  meta = {
    description = "Desktop app for terminals and coding agents that keep running (Herdr)";
    homepage = "https://herdr.dev";
    changelog = "https://github.com/herdrdev/herdr-app/blob/v${finalAttrs.version}/CHANGELOG.md";
    # The binary also bundles libghostty-vt, QuickJS, fonts and icons under
    # other free licenses; see share/licenses/herdr-app/THIRD-PARTY-NOTICES.
    license = with lib.licenses; [
      asl20
      mit
      ofl
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "herdr-app";
    platforms = builtins.attrNames source.targets;
  };
})
