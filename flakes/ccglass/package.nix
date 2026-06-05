{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  bun,
}:
# ccglass is a pure-ESM Node app published as `ccglass` on npm. We build it into a
# single standalone executable with `bun build --compile`. buildNpmPackage gives us
# reproducible node_modules from the upstream package-lock.json (populated offline by
# npmConfigHook before buildPhase); bun then bundles + compiles.
#
# A small fork (fork.patch) is required because the compiled binary cannot do the
# script-relative disk reads upstream relies on:
#   - cli.js reads ../package.json for the version at load   -> hardcode the version
#   - server.js serves web/ via path.join(__dirname, ...)    -> embed assets in the binary
#   - cli.js spawns the MCP server as `process.execPath mcp.js` -> self-exec sentinel
# Re-check the patch on every version bump (see Risks in the plan).
buildNpmPackage (finalAttrs: {
  pname = "ccglass";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "jianshuo";
    repo = "ccglass";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Os7fQh4Egi5WcMXZ7MhIQVNjLI2iRPhbktPqWiq9sTI=";
  };

  npmDepsHash = "sha256-VcPa9YsGS+sUcsGHucPceknhR6J5qoeA4C018qX/dRE=";

  patches = [ ./fork.patch ];

  nativeBuildInputs = [ bun ];
  dontNpmBuild = true; # upstream has no build script; we compile with bun instead

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR # keep bun from touching the real home
    bun build --compile ./bin/ccglass.js --outfile ccglass
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 ccglass $out/bin/ccglass
    runHook postInstall
  '';

  meta = {
    description = "Local logging reverse-proxy + web dashboard that shows what coding agents send to the model";
    homepage = "https://github.com/jianshuo/ccglass";
    license = lib.licenses.mit;
    mainProgram = "ccglass";
    # Pure-JS deps + `bun build --compile` → builds a native binary on darwin and linux.
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
    maintainers = with lib.maintainers; [ kriswill ];
  };
})
