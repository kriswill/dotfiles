{
  stdenv,
  lib,
  fetchFromGitHub,
  nodejs_22,
  gitMinimal,
  gitSetupHook,
  pnpm_8,
  fetchPnpmDeps,
  pnpmConfigHook,
  bun,
  makeWrapper,
  removeReferencesTo,
}:
let
  pnpm' = pnpm_8.override { nodejs = nodejs_22; };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "vtsls";
  version = "0.2.9";

  src = fetchFromGitHub {
    owner = "yioneko";
    repo = "vtsls";
    tag = "server-v${finalAttrs.version}";
    hash = "sha256-vlw84nigvQqRB9OQBxOmrR9CClU9M4dNgF/nrvGN+sk=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    nodejs_22
    gitMinimal
    gitSetupHook
    pnpmConfigHook
    pnpm'
    makeWrapper
    removeReferencesTo
  ];

  buildInputs = [ bun ];

  pnpmWorkspaces = [ "@vtsls/language-server" ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pnpmWorkspaces
      pname
      src
      version
      ;
    pnpm = pnpm';
    fetcherVersion = 1;
    hash = "sha256-SdqeTYRH60CyU522+nBo0uCDnzxDP48eWBAtGTL/pqg=";
  };

  patches = [ ./vtsls-build-patch.patch ];

  env.CI = true;

  buildPhase = ''
    runHook preBuild

    echo "dummysha" > ./packages/service/HEAD

    git init packages/service/vscode

    pnpm --filter "@vtsls/language-server..." build

    rm -rf packages/service/vscode/.git
    rm -rf packages/service/src/typescript-language-features/.git

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib/vtsls-language-server}
    cp -r {packages,node_modules} $out/lib/vtsls-language-server

    # Strip build-time nodejs references from vendored bin script shebangs.
    # The --bun flag on the wrapper ensures bun intercepts node shebangs at runtime.
    find $out/lib/vtsls-language-server -type f -exec remove-references-to -t ${nodejs_22} {} +

    makeWrapper ${bun}/bin/bun $out/bin/vtsls \
      --add-flags "run --bun $out/lib/vtsls-language-server/packages/server/bin/vtsls.js"

    runHook postInstall
  '';

  meta = {
    description = "LSP wrapper for typescript extension of vscode (using bun runtime)";
    homepage = "https://github.com/yioneko/vtsls";
    license = lib.licenses.mit;
    mainProgram = "vtsls";
    platforms = lib.platforms.all;
  };
})
