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
        cognee = prev.cognee.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            api="$out/${python312.sitePackages}/cognee/api"
            install -m644 ${./admin_users.py} "$api/admin_users.py"
            # One seam: mount the router just before the module's entry point.
            substituteInPlace "$api/client.py" \
              --replace-fail 'if __name__ == "__main__":' $'from cognee.api.admin_users import router as admin_users_router\n\napp.include_router(admin_users_router)\n\n\nif __name__ == "__main__":'

            # Credential management must not inherit the optional default user.
            substituteInPlace "$api/v1/api_keys/routers/get_api_key_management_router.py" \
              --replace-fail 'from cognee.modules.users.methods import get_authenticated_user' 'from cognee.modules.users.get_fastapi_users import get_fastapi_users' \
              --replace-fail '    api_key_management_router = APIRouter()' $'    api_key_management_router = APIRouter()\n    require_authenticated_user = get_fastapi_users().current_user(active=True)' \
              --replace-fail 'Depends(get_authenticated_user)' 'Depends(require_authenticated_user)'
          '';
        });
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
