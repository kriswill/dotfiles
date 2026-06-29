{
  lib,
  stdenv,
  fetchFromGitHub,
  gnumake,
  git,
  zlib,
}:
# codebase-memory-mcp is a C MCP server built with a plain Makefile (Makefile.cbm).
# Upstream's own flake (axelbdt/codebase-memory-mcp.nix) is flake-utils-based and
# pins a bare commit; this is the same derivation factored into a callPackage
# function so the flake-parts sub-flake (./flake.nix) can build it. Upstream tags
# every release, so we pin by tag — bump `version` and regenerate `hash` to update.
stdenv.mkDerivation (finalAttrs: {
  pname = "codebase-memory-mcp";
  version = "0.8.1";

  src = fetchFromGitHub {
    owner = "DeusData";
    repo = "codebase-memory-mcp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-H0l8H2JhPT1Rs0p+CJC1a1qYtnZNgLGe6n7PmM+WvE4=";
  };

  nativeBuildInputs = [
    gnumake
    git
  ];

  buildInputs = [ zlib ] ++ lib.optionals stdenv.isLinux [ zlib.static ];

  # Without git/CI present the build defaults CBM_VERSION to "dev" (src/main.c,
  # src/cli/cli.c). Inject the real release via CFLAGS_EXTRA so `--version` and the
  # tool's self-update check report the pinned tag; the escaped quotes survive make's
  # recipe shell so the compiler sees a string literal.
  buildPhase = ''
    make -j''${NIX_BUILD_CORES:-1} -f Makefile.cbm cbm \
      CFLAGS_EXTRA='-DCBM_VERSION=\"${finalAttrs.version}\"'
  '';

  installPhase = ''
    install -Dm755 build/c/codebase-memory-mcp $out/bin/codebase-memory-mcp
  '';

  meta = {
    description = "MCP server for codebase memory and graph indexing";
    homepage = "https://github.com/DeusData/codebase-memory-mcp";
    license = lib.licenses.mit;
    mainProgram = "codebase-memory-mcp";
    platforms = lib.platforms.unix;
  };
})
