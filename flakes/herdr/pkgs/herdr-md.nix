# herdr-md: a markdown viewer mod for Herdr (ryanthedev/herdr-md), and `mdh`,
# the CLI that opens files in it and highlights passages for agents. Upstream
# installs by copying mods/herdr-md into ~/.config/herdr-app/mods, and the mod
# runs `npm install` in its render/ folder the first time it meets a formula.
# Here both are pinned fetches: the repo at `rev`, and the renderer's npm
# dependencies from upstream's package-lock.json (`npmDeps`).
#
# A mod can only be JavaScript that Herdr's own engine loads, but what it runs
# can be anything. So, besides ./herdr-md-linux.patch (Linux support, and a key
# help that reads keys.json), bun builds two files:
#
# - main.js: the mod's eight modules as one. ~/.config/herdr-app/mods/herdr-md
#   has to be a real, writable folder (Herdr writes its typings into every mod
#   folder at start, and the mod keeps its cache there, .cache, reached through
#   appHome()), so the modules (../modules/{nixos,darwin}.nix) link each entry
#   of share/herdr-app/mods/herdr-md into it by name; `modFiles` is that list.
#   Herdr refuses an import that resolves outside the mod's folder ("module
#   `./lex.js` resolves outside the application directory"), which a link into
#   the store does. main.js itself may be a link, as every stowed mod's is, so
#   the bundle leaves it nothing to import but Herdr's own modules.
# - libexec/herdr-md/render.js: the figure renderer (render.mjs, MathJax,
#   mermaid-cli, puppeteer; 838 modules) as one 6 MB file, in place of 430 MB
#   of node_modules. The mod runs it with bun, both by store path, not with
#   whatever `node` the app's PATH has. mermaid-cli has the browser load a page
#   and two scripts it finds beside its own source, which a bundle has none
#   of; they are installed as libexec/herdr-md/mermaid and its three lookups
#   point there. (`bun build --compile` works as well, but wraps the same
#   6 MB in another 100 MB copy of the bun these machines already have.)
#
# Node appears only in the build, where nixpkgs' npm hook unpacks the
# dependencies; disallowedReferences keeps it out of the closure. ffmpeg and
# ffprobe (video frames; image sizes on Linux) fall back to a pinned build when
# PATH has none, and mdh runs a pinned python3 (standard library only).
# Mermaid still needs a Chromium-family browser on PATH (or CHROME_PATH); none
# is pinned.
#
# To update: set `rev` and the date in `version`, then the two hashes (build
# with lib.fakeHash; or `nix flake prefetch github:ryanthedev/herdr-md/<rev>`
# and `prefetch-npm-deps mods/herdr-md/render/package-lock.json`). A patch or
# a substitution that no longer applies fails the build, and so does a file
# upstream adds that nothing here places. The checks run upstream's tests on
# the patched source and render a formula with the installed renderer; draw a
# Mermaid diagram by hand afterwards (the sandbox has no browser).
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchNpmDeps,
  npmHooks,
  nodejs,
  bun,
  python3,
  ffmpeg-headless,
}:
let
  mod = "herdr-md";
  modFiles = [
    "main.js"
    "mdh"
    "mod.json"
  ];
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "herdr-md";
  # Upstream has no tags; the date is the commit's.
  version = "0-unstable-2026-11-17";

  src = fetchFromGitHub {
    owner = "ryanthedev";
    repo = "herdr-md";
    rev = "e96cc755eb1afd18209822b638f1e7664685193e";
    hash = "sha256-vQ0a8kiLwgO4aulJccr/xiR6dqGq19ssg+AFmNypBXQ=";
  };

  # The renderer's dependencies, as npm's tarballs for every platform.
  npmRoot = "mods/herdr-md/render";
  npmDeps = fetchNpmDeps {
    name = "herdr-md-render-npm-deps";
    inherit (finalAttrs) src;
    sourceRoot = "${finalAttrs.src.name}/${finalAttrs.npmRoot}";
    hash = "sha256-0pJOytv6XqgCjLcokS8pfL6ZKP+k0Yr0IckS1GNO0ks=";
  };

  patches = [ ./herdr-md-linux.patch ];

  # The renderer is always there, so skip the probe that would run `npm
  # install`, and run the bundle.
  postPatch = ''
    substituteInPlace mods/herdr-md/main.js \
      --replace-fail 'const has = await exec("test", ["-d", `''${dir}/node_modules/mathjax-full`]);' \
        'const has = { code: 0 };' \
      --replace-fail 'return exec("node", [`''${dir}/render.mjs`, jobs]);' \
        'return exec("${lib.getExe bun}", ["${placeholder "out"}/libexec/herdr-md/render.js", jobs]);' \
      --replace-fail 'PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"' \
        'PATH="$PATH:${lib.makeBinPath [ ffmpeg-headless ]}:/opt/homebrew/bin:/usr/local/bin"'
  '';

  nativeBuildInputs = [
    bun
    nodejs
    npmHooks.npmConfigHook
  ];
  # A host input, so fixup's patchShebangs points mdh at it.
  buildInputs = [ python3 ];

  # No install scripts: puppeteer's would download a Chrome.
  npmRebuildFlags = [ "--ignore-scripts" ];

  dontConfigure = true;

  # gpui-kit, gpui-base and herdr are the app's own modules and stay imports.
  # typescript is only cosmiconfig's loader for a .ts puppeteer config.
  buildPhase = ''
    runHook preBuild

    bun build mods/herdr-md/main.js --outfile bundle/main.js --format=esm --target=browser \
      --external gpui-kit --external gpui-base --external herdr

    substituteInPlace mods/herdr-md/render/node_modules/@mermaid-js/mermaid-cli/src/index.js \
      --replace-fail "path.resolve(path.dirname(url.fileURLToPath(resolve('mermaid', import.meta.url))), 'mermaid.js')" \
        "'$out/libexec/herdr-md/mermaid/mermaid.js'" \
      --replace-fail "path.resolve(path.dirname(url.fileURLToPath(resolve('@mermaid-js/mermaid-zenuml', import.meta.url))), 'mermaid-zenuml.js')" \
        "'$out/libexec/herdr-md/mermaid/mermaid-zenuml.js'" \
      --replace-fail "path.join(__dirname, '..', 'dist', 'index.html')" \
        "'$out/libexec/herdr-md/mermaid/index.html'"
    bun build mods/herdr-md/render/render.mjs --outfile bundle/render.js --format=esm --target=bun \
      --external typescript

    runHook postBuild
  '';

  # Upstream's tests, on the patched source (the modules, before bundling).
  # -B: no __pycache__ beside mdh, where the install check below would trip
  # over it.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    bun test ./test
    python3 -B test/mdh.test.py
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mod=$out/share/herdr-app/mods/${mod}
    libexec=$out/libexec/herdr-md
    deps=mods/herdr-md/render/node_modules
    mkdir -p $mod $libexec/mermaid $out/bin

    install -m644 bundle/main.js mods/herdr-md/mod.json -t $mod
    install -m755 mods/herdr-md/mdh -t $mod
    ln -s ../share/herdr-app/mods/${mod}/mdh $out/bin/mdh

    install -m644 bundle/render.js -t $libexec
    cp -R $deps/@mermaid-js/mermaid-cli/dist/. $libexec/mermaid/
    install -m644 $deps/mermaid/dist/mermaid.js $deps/@mermaid-js/mermaid-zenuml/dist/mermaid-zenuml.js \
      -t $libexec/mermaid

    # The modules link the mod folder's entries by name.
    if ! diff <(ls -A $mod | LC_ALL=C sort) <(printf '%s\n' ${lib.escapeShellArgs modFiles} | LC_ALL=C sort); then
      echo "herdr-md: the installed mod folder (<) and modFiles (>) differ" >&2
      exit 1
    fi
    # Everything upstream ships has to be bundled or placed above.
    if ls -A mods/herdr-md | grep -v -x -E 'mdh|mod\.json|render|marked\.LICENSE\.md|.*\.js' \
      || ls -A mods/herdr-md/render | grep -v -x -E 'node_modules|package(-lock)?\.json|render\.mjs'; then
      echo "herdr-md: upstream ships the files above, which this package doesn't place" >&2
      exit 1
    fi
    if grep -E '(from|import) *"\.' $mod/main.js; then
      echo "herdr-md: the bundled main.js still imports a file" >&2
      exit 1
    fi

    install -Dm644 LICENSE mods/herdr-md/marked.LICENSE.md -t $out/share/licenses/herdr-md
    install -Dm644 README.md -t $out/share/doc/herdr-md
    cp -R demo skills $out/share/doc/herdr-md/

    runHook postInstall
  '';

  disallowedReferences = [ nodejs ];

  # mdh starts, and the renderer works as the viewer runs it. Only a formula:
  # Mermaid needs a browser.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/mdh --help > /dev/null
    ${lib.getExe bun} $out/libexec/herdr-md/render.js \
      '[{"kind":"math","src":"x^2","out":"'"$TMPDIR"'/formula.svg"}]' > /dev/null
    grep -q '<svg' "$TMPDIR/formula.svg"
    runHook postInstallCheck
  '';

  passthru = {
    inherit mod modFiles;
  };

  meta = {
    description = "Markdown viewer mod for Herdr, and mdh, the CLI that opens files in it and highlights passages";
    homepage = "https://github.com/ryanthedev/herdr-md";
    # MIT: the mod, the marked bundled into main.js, mermaid and mermaid-cli.
    # Apache-2.0: MathJax and puppeteer. render.js carries their dependencies
    # too, under their own licenses.
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "mdh";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
