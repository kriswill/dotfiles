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
  version = "1.6.11";

  src = fetchFromGitHub {
    owner = "topoteretes";
    repo = "cognee";
    tag = "v${finalAttrs.version}";
    hash = "sha256-/ZqNENrZAG02TTvW8CkVStUrNCaXyGSi7TvaiwNCrKQ=";
  };
  sourceRoot = "${finalAttrs.src.name}/cognee-frontend";
  npmDepsHash = "sha256-UDUVo15T5lUuqJ3013On2BMKUdVOMP9t1xIUwwlVJyg=";
  nodejs = nodejs_22;
  # Restyling of upstream's own markup, which no overlay can carry: the
  # sign-in form without pre-filled credentials, and a top bar that fits a
  # phone. Everything else is a feature under ./dashboard.
  patches = [
    ./dashboard-login.patch
    ./dashboard-topbar-narrow.patch
  ];
  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    # Self-standing features are real source under ./dashboard/<feature>,
    # mirroring the paths they land at, and are laid over the upstream tree.
    # A path upstream already has is a build error, never an overwrite.
    for overlay in ${./dashboard}/*/; do
      while IFS= read -r -d "" file; do
        if [ -e "$file" ]; then
          echo "dashboard overlay $(basename "$overlay") collides with upstream file $file" >&2
          exit 1
        fi
        install -Dm644 "$overlay$file" "$file"
      done < <(cd "$overlay" && find . -type f -print0)
    done

    # The only upstream edit Manage Users needs: mount its sidebar section.
    substituteInPlace src/ui/layout/Navbar/CustomAppShellNavbar.tsx \
      --replace-fail 'import NavbarFooter from "./NavbarFooter";' $'import NavbarFooter from "./NavbarFooter";\nimport ManageUsersNav from "@/modules/admin-users/ManageUsersNav";' \
      --replace-fail '        </nav>' $'          <ManageUsersNav />\n        </nav>'

    # Seams: where upstream's files hand over to a feature. Each is an anchor
    # that must still exist upstream and its replacement; nothing else in
    # this section edits upstream.
    importAfter() { substituteInPlace "$1" --replace-fail "$2" "$2"$'\n'"$3"; }
    wrapWith() { substituteInPlace "$1" --replace-fail "$2" "$3$2$4"; }

    # api-keys: upstream's three API-key stubs keep their types and
    # signatures and call the local backend.
    substituteInPlace src/modules/apiKeys/createAPIKey.ts \
      --replace-fail 'export default async function createApiKey(' $'import { createLocalApiKey } from "@/modules/local-api-keys/localApiKeys";\n\nexport default async function createApiKey(' \
      --replace-fail $'  console.warn("API key creation requires Cognee Cloud.");\n  return { ok: false, error: "API key creation requires Cognee Cloud." };' '  return createLocalApiKey(_options);'
    substituteInPlace src/modules/apiKeys/getApiKeys.ts \
      --replace-fail 'export default async function getApiKeys(' $'import { listLocalApiKeys } from "@/modules/local-api-keys/localApiKeys";\n\nexport default async function getApiKeys(' \
      --replace-fail '  return [];' '  return listLocalApiKeys();'
    substituteInPlace src/modules/apiKeys/deleteAPIKey.ts \
      --replace-fail 'export default async function deleteApiKey(' $'import { revokeLocalApiKey } from "@/modules/local-api-keys/localApiKeys";\n\nexport default async function deleteApiKey(' \
      --replace-fail '  console.warn("API key management requires Cognee Cloud.");' '  return revokeLocalApiKey(_keyId);'

    # api-keys: the pages that open the agent setup modal open the wrapper
    # that can create a key. A new importer upstream would bypass it.
    for site in 'src/app/(app)/dashboard/OverviewPage.tsx' 'src/app/(app)/integrations/partials/SetupConnectorSection.tsx'; do
      substituteInPlace "$site" \
        --replace-fail 'import { AgentSetupModal } from "@/ui/elements/AgentSetupModal";' 'import { LocalAgentSetupModal as AgentSetupModal } from "@/modules/local-agent-setup/LocalAgentSetupModal";'
    done
    if grep -rl --include='*.ts' --include='*.tsx' --exclude-dir=__tests__ --exclude-dir=local-agent-setup '/AgentSetupModal"' src >&2; then
      echo "the files above import AgentSetupModal without the local API-key wrapper" >&2
      exit 1
    fi

    # memory-reader: a reader scope around each of the two document lists,
    # and the name in each row. The files table also stops throwing on a
    # name that is not valid percent-encoding.
    datasetPage='src/app/(app)/datasets/[id]/page.tsx'
    importAfter "$datasetPage" 'import DatasetDetailPage from "./DatasetDetailPage";' 'import { MemoryReaderScope } from "@/modules/memory-reader/ReaderScope";'
    wrapWith "$datasetPage" '<DatasetDetailPage datasetId={id} />' '<MemoryReaderScope datasetId={id}>' '</MemoryReaderScope>'
    filesTable='src/app/(app)/datasets/[id]/partials/FilesTable.tsx'
    substituteInPlace "$filesTable" \
      --replace-fail 'import { formatDate, formatFileSize } from "@/utils/fileFormat";' $'import { decodeFilename, formatDate, formatFileSize } from "@/utils/fileFormat";\nimport { ReadableFileName } from "@/modules/memory-reader/ReadableName";' \
      --replace-fail 'decodeURIComponent(file.name)' 'decodeFilename(file.name)'
    wrapWith "$filesTable" '<span title={repository ?? undefined} style={{ fontSize: 13, fontWeight: 500, color: "#EDECEA" }}>{displayName}</span>' '<ReadableFileName file={file} title={displayName}>' '</ReadableFileName>'
    documentsPanel='src/app/(app)/datasets/partials/DocumentsPanel.tsx'
    importAfter "$documentsPanel" 'import DocumentList, { type DocRow } from "./DocumentList";' 'import { MemoryReaderScope } from "@/modules/memory-reader/ReaderScope";'
    wrapWith "$documentsPanel" '<DocumentList docs={docs} onDelete={onDeleteDoc} />' '<MemoryReaderScope datasetId={selectedId}>' '</MemoryReaderScope>'
    documentList='src/app/(app)/datasets/partials/DocumentList.tsx'
    importAfter "$documentList" 'import ProcessingBadge from "./ProcessingBadge";' 'import { ReadableDocumentName } from "@/modules/memory-reader/ReadableName";'
    wrapWith "$documentList" '<span style={{ flex: 1, fontSize: 13, color: "#EDECEA", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{displayName}</span>' '<ReadableDocumentName doc={doc} title={displayName}>' '</ReadableDocumentName>'

    # releases: /releases renders the feature's page, and upstream's shared
    # query validates this deployment's route and refreshes every 15 minutes.
    substituteInPlace 'src/app/(app)/releases/page.tsx' \
      --replace-fail 'import ReleasesPage from "./ReleasesPage";' 'import ReleasesPage from "@/modules/self-hosted-releases/ReleaseNotesPage";'
    substituteInPlace src/modules/releases/useReleases.ts \
      --replace-fail 'import { parseReleaseLog } from "./releaseLog";' 'import { parseDeploymentReleaseLog, type DeploymentReleaseLog } from "@/modules/self-hosted-releases/releaseLog";' \
      --replace-fail 'http.getJson<ReleaseLog>("/api/releases", { validate: parseReleaseLog }),' $'http.getJson<DeploymentReleaseLog>("/api/releases", { validate: parseDeploymentReleaseLog }),\n    refetchInterval: 15 * 60_000,'

    # releases: the help menu leaves a deployment's notes to that page and
    # names the product, and the update link sits just before its button.
    # (The menu is the top bar's own child and returns a fragment, so the
    # link is a top bar item; mounting it here keeps TopBar.tsx unedited.)
    helpMenu=src/ui/layout/HelpMenu.tsx
    importAfter "$helpMenu" 'import { useReleases } from "@/modules/releases/useReleases";' 'import UpdateAvailableLink from "@/modules/self-hosted-releases/UpdateAvailableLink";'
    substituteInPlace "$helpMenu" \
      --replace-fail '{extractionOpen && <ExtractionSettingsModal' $'<UpdateAvailableLink />\n    {extractionOpen && <ExtractionSettingsModal' \
      --replace-fail 'const latestRelease = releaseLog?.available ?' 'const latestRelease = releaseLog?.available && !releaseLog.upstream ?' \
      --replace-fail ') : releaseLog?.available ? (' ') : releaseLog?.available && !releaseLog.upstream ? (' \
      --replace-fail 'Cloud {runningVersion}' '{releaseLog?.upstream ? "Cognee" : "Cloud"} {runningVersion}'

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

  # Every feature's tests. They exercise the upstream modules the features
  # import and the upstream files they are mounted in, so a version bump
  # that breaks that contract fails here.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    featureTests=()
    for overlay in ${./dashboard}/*/; do
      while IFS= read -r -d "" file; do
        featureTests+=("$file")
      done < <(cd "$overlay" && find . -type f \( -name "*.test.ts" -o -name "*.test.tsx" \) -print0)
    done
    if [ "''${#featureTests[@]}" -eq 0 ]; then
      echo "no dashboard feature tests found" >&2
      exit 1
    fi
    npx --no-install jest --ci --runTestsByPath "''${featureTests[@]}"
    runHook postCheck
  '';

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
