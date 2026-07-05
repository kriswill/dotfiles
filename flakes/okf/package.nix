{
  lib,
  stdenvNoCC,
  bun,
  git,
  makeBinaryWrapper,
}:
# okf runs from source under bun — `okf viz` bundles the Svelte viewer with
# Bun.build + bun-plugin-svelte at CLI runtime, so `bun build --compile` is out;
# the package ships the TypeScript tree plus vendored node_modules and a bun
# wrapper. Deps are a fixed-output `bun install` (no bun packaging helper exists
# in nixpkgs; this mirrors its opencode/helix-gpt packages). The repo okf
# operates on is resolved from the caller's working directory (lib.ts), never
# from the store path.
let
  # Explicit include-list: nix plumbing stays out (nix-only edits don't rebuild
  # the package) and node_modules can never leak in however the source reaches us.
  sources = lib.fileset.unions [
    ./okf.ts
    ./init.ts
    ./lib.ts
    ./config-cli.ts
    ./vcs
    ./scaffold.ts
    ./scaffold-api.ts
    ./index-gen.ts
    ./validate.ts
    ./viz.ts
    ./viz-perf.ts
    ./layout3d.ts
    ./tsconfig.json
    ./package.json
    ./bun.lock
    ./bunfig.toml
    ./viz-app
    ./test
  ];

  # Tests stay out of the shipped package: bun's test scanner follows the
  # `result` symlink `nix build` leaves in the flake root, so any *.test.ts
  # under $out would run as a stale second copy of the suite.
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.difference sources (
      lib.fileset.unions [
        ./test
        (lib.fileset.fileFilter (file: lib.hasSuffix ".test.ts" file.name) ./viz-app)
      ]
    );
  };

  # Full tree including the tests — only checks.test builds from this.
  testSrc = lib.fileset.toSource {
    root = ./.;
    fileset = sources;
  };

  # One hash serves every platform: --cpu/--os="*" makes bun install every
  # platform variant of os/cpu-conditional packages (@typescript/native-preview
  # ships a ~26M tsgo binary per platform — the bulk of this output's size).
  # No install scripts run. NOT --production: `okf viz` needs svelte +
  # bun-plugin-svelte (devDependencies) at CLI runtime, the tests happy-dom.
  # Refresh the hash (bun.lock or nixpkgs bun changes): set lib.fakeHash, then
  # `nix build ./flakes/okf#okf.node_modules` and copy the "got:" value.
  node_modules = stdenvNoCC.mkDerivation {
    pname = "okf-node_modules";
    version = "0";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [
        ./package.json
        ./bun.lock
      ];
    };
    nativeBuildInputs = [ bun ];
    dontConfigure = true;
    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];
    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
      bun install \
        --frozen-lockfile \
        --ignore-scripts \
        --no-progress \
        --cpu="*" \
        --os="*"
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir $out
      cp -R node_modules $out/node_modules
      runHook postInstall
    '';
    # Fixup would patch shebangs into store paths — forbidden in a fixed-output
    # derivation.
    dontFixup = true;
    outputHash = "sha256-NBnA/LycPFkpSkvkpZCv6dmK8v6Da6OAI5ADYq7TuAI=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };
in
stdenvNoCC.mkDerivation {
  pname = "okf";
  version = "0.1.0";
  inherit src;

  nativeBuildInputs = [ makeBinaryWrapper ];
  dontConfigure = true;
  dontBuild = true;

  # bun resolves imports by walking the entry file's parent directories, so the
  # node_modules symlink beside the sources is found and followed; --no-install
  # forbids any runtime fetch. git backs lib.ts's spawns (repo root, log, ls-files).
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/okf $out/bin
    cp -R . $out/lib/okf
    ln -s ${node_modules}/node_modules $out/lib/okf/node_modules
    makeBinaryWrapper ${lib.getExe bun} $out/bin/okf \
      --add-flags "run --prefer-offline --no-install" \
      --add-flags "$out/lib/okf/okf.ts" \
      --set-default OKF_PROG okf \
      --prefix PATH : ${
        lib.makeBinPath [
          bun
          git
        ]
      }
    runHook postInstall
  '';

  passthru = {
    inherit node_modules;
    # `bun test` offline against the vendored deps; surfaced as checks.test.
    # git matches the runtime wrapper's PATH and lets the gitProvider tests
    # run instead of skipIf-skipping.
    tests.unit = stdenvNoCC.mkDerivation {
      name = "okf-tests";
      src = testSrc;
      nativeBuildInputs = [
        bun
        git
      ];
      dontConfigure = true;
      buildPhase = ''
        runHook preBuild
        export HOME=$TMPDIR
        export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
        ln -s ${node_modules}/node_modules node_modules
        bun test
        runHook postBuild
      '';
      installPhase = "touch $out";
    };
  };

  meta = {
    description = "CLI for maintaining OKF knowledge bundles (scaffold/index/validate/viz)";
    # TODO(extraction): flips to the standalone repo URL when okf moves out.
    homepage = "https://github.com/kriswill/dotfiles/tree/main/flakes/okf";
    mainProgram = "okf";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = [ { github = "kriswill"; } ];
  };
}
