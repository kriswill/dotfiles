# Modified version of this derivation to allow running on aarch64-darwin,
# using Chromium (installed via homebrew) with hard-coded path
# Original: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/aw/aws-azure-login/package.nix
{
  lib,
  callPackage,
  stdenv,
  fetchFromGitHub,
  fetchYarnDeps,
  makeWrapper,
  nodejs,
  fixup-yarn-lock,
  yarn,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "aws-azure-login";
  version = "3.6.3";

  src = fetchFromGitHub {
    owner = "aws-azure-login";
    repo = "aws-azure-login";
    rev = "v${finalAttrs.version}";
    hash = "sha256-nKgsckASg9hY4/0EXN3HYGN2n5aYV1FhKE2N4hqbG9w=";
  };

  offlineCache = fetchYarnDeps {
    yarnLock = "${finalAttrs.src}/yarn.lock";
    hash = "sha256-Hsba6fz/Omp1sei7tKi7E+f2x5cNJveRgKNS2exUKFg=";
  };

  nativeBuildInputs = [
    makeWrapper
    nodejs
    fixup-yarn-lock
    yarn
  ];

  configurePhase = ''
    runHook preConfigure

    export HOME=$(mktemp -d)
    yarn config --offline set yarn-offline-mirror "$offlineCache"
    fixup-yarn-lock yarn.lock
    yarn --offline --frozen-lockfile --ignore-platform --ignore-scripts --no-progress --non-interactive install
    patchShebangs node_modules

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    yarn --offline build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    yarn --offline --production install

    mkdir -p "$out/lib/node_modules/aws-azure-login"
    cp -r . "$out/lib/node_modules/aws-azure-login"

    # custom wrapper specifically for homebrew install path for Chromium
    makeWrapper "${nodejs}/bin/node" "$out/bin/aws-azure-login" \
      --add-flags "$out/lib/node_modules/aws-azure-login/lib/index.js" \
      --set PUPPETEER_EXECUTABLE_PATH "/opt/homebrew/bin/chromium"

    runHook postInstall
  '';

  meta = {
    description = "Use Azure AD SSO to log into the AWS via CLI (macOS with Homebrew Chromium)";
    homepage = "https://github.com/aws-azure-login/aws-azure-login";
    license = lib.licenses.mit;
    mainProgram = "aws-azure-login";
    platforms = [ "aarch64-darwin" ];
  };
})
