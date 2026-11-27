{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  geist-font,
  makeWrapper,
  nodejs_22,
}:
buildNpmPackage (finalAttrs: {
  pname = "cognee-frontend";
  version = "1.6.10";

  src = fetchFromGitHub {
    owner = "topoteretes";
    repo = "cognee";
    tag = "v${finalAttrs.version}";
    hash = "sha256-xqZq/fEKkHduShQH5IQfr+bwLnRLpYiELsk6fH7GfQI=";
  };
  sourceRoot = "${finalAttrs.src.name}/cognee-frontend";
  npmDepsHash = "sha256-UDUVo15T5lUuqJ3013On2BMKUdVOMP9t1xIUwwlVJyg=";
  nodejs = nodejs_22;
  patches = [
    ./dashboard-login.patch
    ./dashboard-api-keys.patch
  ];
  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    # The browser uses Caddy's HTTPS origin. Server-side routes use loopback.
    substituteInPlace src/modules/config/serverRuntimeConfig.ts \
      --replace-fail '  return (' $'  return (\n    normalizeBackendUrl(process.env.COGNEE_INTERNAL_BACKEND_URL, "COGNEE_INTERNAL_BACKEND_URL") ??'
    substituteInPlace src/app/api/local-signout/route.ts \
      --replace-fail 'NextResponse.redirect(new URL("/local-login", request.url))' \
        'new NextResponse(null, { status: 307, headers: { Location: "/local-login" } })'

    # Serve original images from the immutable bundle without a writable cache.
    substituteInPlace next.config.ts --replace-fail '  images: {' '  images: { unoptimized: true,'

    # Use the packaged variable fonts for a network-free Next.js build.
    install -m644 "${geist-font}/share/fonts/truetype/Geist[wght].ttf" src/app/Geist.ttf
    install -m644 "${geist-font}/share/fonts/truetype/GeistMono[wght].ttf" src/app/GeistMono.ttf
    substituteInPlace src/app/layout.tsx \
      --replace-fail 'import { Geist, Geist_Mono } from "next/font/google";' 'import localFont from "next/font/local";' \
      --replace-fail 'Geist({' 'localFont({ src: "./Geist.ttf",' \
      --replace-fail 'Geist_Mono({' 'localFont({ src: "./GeistMono.ttf",' \
      --replace-fail 'subsets: ["latin"],' 'weight: "100 900",'
  '';

  env.NEXT_TELEMETRY_DISABLED = "1";

  installPhase = ''
    runHook preInstall

    app="$out/lib/cognee-frontend"
    mkdir -p "$app/.next" "$out/bin"
    cp -R .next/standalone/. "$app/"
    cp -R .next/static "$app/.next/"
    cp -R public "$app/"
    makeWrapper ${lib.getExe nodejs_22} "$out/bin/cognee-frontend" \
      --add-flags "$app/server.js" \
      --set-default HOSTNAME 127.0.0.1 \
      --set NEXT_TELEMETRY_DISABLED 1

    runHook postInstall
  '';

  meta = {
    description = "Cognee memory dashboard and knowledge graph explorer";
    homepage = "https://github.com/topoteretes/cognee/tree/main/cognee-frontend";
    license = lib.licenses.asl20;
    mainProgram = "cognee-frontend";
    platforms = [ "aarch64-darwin" ];
  };
})
