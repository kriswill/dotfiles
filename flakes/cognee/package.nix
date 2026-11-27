{
  lib,
  callPackage,
  darwin,
  openssl,
  python312,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
}:
let
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
  pythonSet = (callPackage pyproject-nix.build.packages { python = python312; }).overrideScope (
    lib.composeManyExtensions [
      # The pinned Ladybug release ships its arm64 wheel for macOS 15+.
      # Set the wheel selection target without rebuilding the Python interpreter.
      (_final: prev: {
        stdenv = prev.stdenv // {
          targetPlatform = prev.stdenv.targetPlatform // {
            darwinSdkVersion = "15.0";
          };
        };
      })
      pyproject-build-systems.overlays.default
      (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
      (final: prev: {
        # langdetect ships a setup.py sdist without build-system metadata.
        langdetect = prev.langdetect.overrideAttrs (old: {
          nativeBuildInputs = old.nativeBuildInputs ++ [ final.setuptools ];
        });
        # The macOS wheel links to the upstream build machine's Homebrew prefix.
        ladybug = prev.ladybug.overrideAttrs (old: {
          nativeBuildInputs = old.nativeBuildInputs ++ [ darwin.sigtool ];
          postFixup = (old.postFixup or "") + ''
            extension=$(echo "$out"/${python312.sitePackages}/ladybug/_lbug*.so)
            install_name_tool \
              -change /opt/homebrew/opt/openssl@3/lib/libssl.3.dylib ${lib.getLib openssl}/lib/libssl.3.dylib \
              -change /opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib ${lib.getLib openssl}/lib/libcrypto.3.dylib \
              "$extension"
            codesign --force --sign - "$extension"
          '';
        });
      })
    ]
  );
in
pythonSet.mkVirtualEnv "cognee" {
  cognee = [ "postgres-binary" ];
}
