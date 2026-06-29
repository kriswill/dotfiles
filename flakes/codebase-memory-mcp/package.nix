{
  lib,
  stdenv,
  fetchFromGitHub,
  buildNpmPackage,
  gnumake,
  git,
  zlib,
}:
# codebase-memory-mcp is a C MCP server built with a plain Makefile (Makefile.cbm).
# Upstream's own flake (axelbdt/codebase-memory-mcp.nix) is flake-utils-based and
# pins a bare commit; this is the same derivation factored into a callPackage
# function so the flake-parts sub-flake (./flake.nix) can build it. Upstream tags
# every release, so we pin by tag — run the adjacent ./update to bump version + hash.
#
# We build the `cbm-with-ui` target, not the plain `cbm`: it links the graph-ui
# web visualizer (an embedded HTTP server reachable via `--ui=true`, default port
# 9749) into the binary. The Makefile's `frontend` target normally runs
# `npm ci && npm run build`, which needs network and so can't run in the Nix
# sandbox. Instead we build graph-ui/dist offline in a separate buildNpmPackage
# derivation, neutralize the `frontend` target, and drop the prebuilt dist in
# place so the `embed` step (pure shell + cc) can turn it into linkable objects.
let
  version = "0.8.1";

  src = fetchFromGitHub {
    owner = "DeusData";
    repo = "codebase-memory-mcp";
    tag = "v${version}";
    hash = "sha256-H0l8H2JhPT1Rs0p+CJC1a1qYtnZNgLGe6n7PmM+WvE4=";
  };

  # graph-ui — the Vite/React/Three.js 3D graph visualizer. Built offline so its
  # dist/ can be embedded into the binary. npmDepsHash pins the vendored npm
  # dependency closure (from graph-ui/package-lock.json); bump it alongside the
  # src hash whenever upstream changes the frontend's lockfile.
  graph-ui = buildNpmPackage {
    pname = "codebase-memory-mcp-graph-ui";
    inherit version src;
    sourceRoot = "${src.name}/graph-ui";
    npmDepsHash = "sha256-feoZNsZfrPgoLdjlnnh3w3vTxR6AwPdUkPubaR93TAk=";

    # `npm run build` = `tsc -b && vite build` → dist/. Override the default
    # npm-install step (this isn't an installable npm package, just static assets).
    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "codebase-memory-mcp";
  inherit version src;

  # Teach the C definition-extractor about Nix's AST so .nix files contribute
  # symbols (bindings -> Variables named by attrpath, named lambdas -> Functions)
  # instead of just a file-level Module node. Upstream wires the Nix language spec
  # but its generic name-resolution can't name Nix's shapes; see the patch header.
  # Only touches internal/cbm/ — the graph-ui sub-derivation (own sourceRoot) is
  # unaffected. Re-validate against extract_defs.c/lang_specs.c on each version bump.
  patches = [ ./nix-symbols.patch ];

  nativeBuildInputs = [
    gnumake
    git
  ];

  buildInputs = [ zlib ] ++ lib.optionals stdenv.isLinux [ zlib.static ];

  # Neutralize the npm-driven `frontend` Makefile target — the Nix sandbox has no
  # network, so we supply graph-ui's prebuilt dist instead (see buildPhase). The
  # `embed` step still runs on that dist (pure shell + cc) and `cbm-with-ui` links
  # the generated objects in.
  postPatch = ''
    substituteInPlace Makefile.cbm \
      --replace-fail 'cd graph-ui && npm ci && npm run build' 'true'
  '';

  # Drop the prebuilt frontend into graph-ui/dist before building. Without git/CI
  # present the build defaults CBM_VERSION to "dev" (src/main.c, src/cli/cli.c);
  # inject the real release via CFLAGS_EXTRA so `--version` and the tool's
  # self-update check report the pinned tag (the escaped quotes survive make's
  # recipe shell so the compiler sees a string literal).
  buildPhase = ''
    runHook preBuild
    mkdir -p graph-ui/dist
    cp -r ${graph-ui}/. graph-ui/dist/
    make -j''${NIX_BUILD_CORES:-1} -f Makefile.cbm cbm-with-ui \
      CFLAGS_EXTRA='-DCBM_VERSION=\"${finalAttrs.version}\"'
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 build/c/codebase-memory-mcp $out/bin/codebase-memory-mcp
    runHook postInstall
  '';

  meta = {
    description = "MCP server for codebase memory and graph indexing";
    homepage = "https://github.com/DeusData/codebase-memory-mcp";
    license = lib.licenses.mit;
    mainProgram = "codebase-memory-mcp";
    platforms = lib.platforms.unix;
  };
})
