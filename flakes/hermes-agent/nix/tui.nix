# Self-contained Hermes TUI, compiled by the same recipe as npm.
{ hermesNpmLib, bun, ... }:
hermesNpmLib.buildNpmPackage {
  dirs = [
    "ui-tui"
    "apps/shared"
    "scripts/build/tui.mjs"
    "scripts/build/freshness.mjs"
    "scripts/build/frontend-common.mjs"
  ];

  # Ours: the Ink TUI must maintain the same continuation breadcrumbs as the
  # classic CLI, including accepted attachment changes and compaction.
  patches = [ ./tui-terminal-breadcrumbs.patch ];
  postPatch = ''
    cp ${./tui-breadcrumbs/terminalBreadcrumbs.ts} ui-tui/src/lib/terminalBreadcrumbs.ts
    cp ${./tui-breadcrumbs/terminalBreadcrumbs.test.ts} ui-tui/src/lib/terminalBreadcrumbs.test.ts
  '';
  nativeBuildInputs = [ bun ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    bun test ui-tui/src/lib/terminalBreadcrumbs.test.ts
    runHook postCheck
  '';

  buildPhase = ''
    runHook preBuild
    node scripts/build/tui.mjs --source "$PWD" --out "$TMPDIR/tui-product"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/hermes-tui
    cp -r "$TMPDIR/tui-product/." $out/lib/hermes-tui/
    runHook postInstall
  '';
}
