# Herdr, the desktop app: upstream's release build, changed only as far as its
# platform needs to run from the Nix store. Version and hashes:
# ../sources.json, refreshed by ../update.ts.
#
# Linux: a GPUI/wgpu binary, patchelf'd to find its libraries. No wrapper here,
# and no LD_LIBRARY_PATH or PATH anywhere: the app passes its environment to
# herdr-core, which passes it to every terminal it starts, so anything set
# here would leak into every shell. The libraries it dlopens go on its RUNPATH
# instead. ./herdr-app-wrap.nix adds the telemetry and settings choices on top.
#
# The Linux self-updater stays off: it only arms when herdr-app.svg sits
# beside the running binary (upstream src/update.rs `find_root`), so the icon
# goes to share/icons and installCheck makes sure of it. With no install
# folder to replace, the app also skips its own update checks; a nix-store
# herdr-core is "managed" and never offered an update either.
#
# macOS: upstream's Developer ID-signed Herdr.app, copied whole into
# Applications/ with no fixup at all (strip or install_name_tool would break
# the signature), plus bin/herdr-app into the bundle's binary for the CLI
# (`herdr-app ls|do|status`). A bundle is always an install root to the
# updater, so it can't be disarmed by layout; it stages a download BESIDE its
# bundle (`Herdr.app.download.noindex`), and nix-darwin copies the bundle into
# "/Applications/Nix Apps", which root owns, so the user's app gets EACCES
# there, logs a warning and retries in 30 minutes, once upstream is ahead
# (herdr-update-check tells you the same thing, once a day). Finder launches
# the bundle itself, not a wrapper, so telemetry and the core pin are
# settings.json keys there, written by ../modules/darwin.nix.
{
  lib,
  stdenv,
  stdenvNoCC,
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
  inherit (stdenv.hostPlatform) system isDarwin isLinux;
  # No compiler is needed anywhere, but autoPatchelf wants stdenv's cc for libgcc_s.
  env = if isDarwin then stdenvNoCC else stdenv;
in
env.mkDerivation (
  finalAttrs:
  {
    pname = "herdr-app-unwrapped";
    inherit (source) version;

    src = fetchurl {
      inherit (source.targets.${system} or (throw "herdr-app: no release build for ${system}")) url hash;
    };

    dontConfigure = true;
    dontBuild = true;

    # Not on macOS: running the signed bundle's executable at build time makes
    # macOS stamp it with com.apple.macl, which the nix daemon may not strip
    # (see herdr-core.nix); the darwin preInstallCheck reads Info.plist instead.
    nativeInstallCheckInputs = lib.optional (!isDarwin) versionCheckHook;
    versionCheckProgram = "${placeholder "out"}/bin/herdr-app";
    doInstallCheck = true;

    # The oldest herdr-core this release accepts (its manifest's core_min); the
    # modules warn when the configured core is older.
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
  }
  // lib.optionalAttrs isLinux {
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

    preInstallCheck = ''
      if [ -e $out/libexec/herdr-app/herdr-app.svg ]; then
        echo "herdr-app.svg beside the binary would arm the self-updater" >&2
        exit 1
      fi
    '';
  }
  // lib.optionalAttrs isDarwin {
    # The tarball holds Herdr.app alone; stay above it rather than inside it.
    sourceRoot = ".";
    # The signature covers every file in the bundle.
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/Applications $out/bin
      cp -R Herdr.app $out/Applications/
      ln -s ../Applications/Herdr.app/Contents/MacOS/Herdr $out/bin/herdr-app
      install -Dm644 Herdr.app/Contents/Resources/{LICENSE,THIRD-PARTY-NOTICES} -t $out/share/licenses/herdr-app
      runHook postInstall
    '';

    # The copy must still carry upstream's signature (skipped where codesign
    # isn't reachable, as in a sandboxed build).
    preInstallCheck = ''
      grep -q "<key>CFBundleShortVersionString</key><string>${finalAttrs.version}</string>" \
        $out/Applications/Herdr.app/Contents/Info.plist \
        || { echo "Herdr.app is not version ${finalAttrs.version}" >&2; exit 1; }
      if [ -x /usr/bin/codesign ]; then
        /usr/bin/codesign --verify --deep --strict $out/Applications/Herdr.app
      fi
    '';
  }
)
