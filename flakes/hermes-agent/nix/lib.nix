# nix/lib.nix — Shared helpers for nix stuff
#
# All JS packages in this repo are pnpm workspace members sharing a single
# root pnpm-lock.yaml.  buildPnpmPackage provides the shared pnpmDeps,
# pnpm and pnpmConfigHook so individual .nix files don't duplicate them.
#
# Source filters (pythonSrc, per-package npm srcs) reduce rebuild scope so
# that e.g. a .tsx change doesn't trigger a Python venv rebuild, and a .py
# change doesn't trigger a TUI/Web/Desktop rebuild.  Each derivation gets a
# filtered src that only includes files it actually needs, while keeping
# the repo-root directory layout intact for pnpmConfigHook workspace
# resolution.
#
# Ours: the tree is hermesSrc (see packages.nix), and pnpm-deps-hash is read
# from it as data. Dropped the node-gyp export, updatePnpmLockfile (a script
# for upstream's checkout) and the dev-shell pnpm hook.
{
  lib,
  stdenv,
  fetchPnpmDeps,
  pnpmConfigHook,
  nodejs-slim,
  callPackage,
  runCommand,
  # pm/lock.json pins, used for node, npm and pnpm.
  pmPackages,
  hermesSrc,
}:
let
  repoRoot = hermesSrc;

  # Every JS tool comes from pm/lock.json — the node the builds and the
  # shipped app run on, npm wrapped onto it, and the pnpm that installs the
  # workspaces. nixpkgs supplies nothing here; node/npm/pnpm have Linux
  # artifacts in the lock.
  pmNode = pmPackages.node;
  npm12 = callPackage ./npm-pinned.nix { nodejs = pmNode; };
  # nixpkgs' pnpm packages build from the `pnpm` npm package, which since
  # pnpm 11 is only a launcher that downloads the native executable, and the
  # pinned nixpkgs has no pnpm_12 anyway; pm's pnpm is that executable.
  # fetchPnpmDeps runs its store normalizer (pnpm-fixup-state-db) on
  # `pnpm.nodejs-slim`, which only nixpkgs' pnpm carries. That helper only
  # rewrites the fetched store's index, so nixpkgs' node runs it.
  pnpm = pmPackages.pnpm // {
    inherit nodejs-slim;
  };
  # bin/npm and bin/npx are the pinned npm; the rest of the tree (node,
  # include/node headers, lib/node_modules/node's own bundled npm) is the
  # pinned node. A plain symlinkJoin cannot express that: both paths carry
  # bin/npm, so assemble it explicitly.
  nodejs =
    runCommand "nodejs-26-npm-12"
      {
        # lib.getExe reads meta.mainProgram; the pm derivation carries no meta.
        meta.mainProgram = "node";
      }
      ''
        cp -rs ${pmNode} $out
        # cp -r copies the store's read-only directory modes; make the farm's own
        # directories writable so bin/npm and bin/npx can be replaced. Only real
        # directories are chmodded, never the symlink targets.
        find $out -type d -exec chmod u+w {} +
        rm -f $out/bin/npm $out/bin/npx
        ln -s ${npm12}/bin/npm $out/bin/npm
        ln -s ${npm12}/bin/npx $out/bin/npx
      '';

  # ── pnpm workspace discovery ───────────────────────────────────────
  # Single source of truth: the `packages` list of pnpm-workspace.yaml.
  # Everything below (workspace package.json discovery, the Python
  # source's JS-dir exclusions) is derived from this so the topology is
  # never duplicated.  Add a workspace to pnpm-workspace.yaml and the nix
  # build picks it up automatically.  Nix reads no YAML: this parses the
  # one shape the file uses (a top-level `packages:` key followed by
  # `  - <dir>` / `  - <dir>/*` lines) and throws on anything else, so a
  # reformatted list cannot silently drop a workspace.
  workspaceYamlLines = lib.splitString "\n" (builtins.readFile (repoRoot + "/pnpm-workspace.yaml"));
  workspacePatterns =
    let
      start = lib.lists.findFirstIndex (
        line: line == "packages:"
      ) (builtins.length workspaceYamlLines) workspaceYamlLines;
      block = lib.drop (start + 1) workspaceYamlLines;
      count = lib.lists.findFirstIndex (line: !lib.hasPrefix "  - " line) (builtins.length block) block;
      items = lib.take count block;
      next = builtins.head (lib.drop count block ++ [ "" ]);
      patterns = map (lib.removePrefix "  - ") items;
      supported = pattern: builtins.match "[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*(/\\*)?" pattern != null;
    in
    if
      items == [ ] || lib.hasPrefix " " next || lib.hasPrefix "-" next || !(lib.all supported patterns)
    then
      throw "nix/lib.nix: pnpm-workspace.yaml `packages:` is no longer a block of unquoted `  - <dir>` or `  - <dir>/*` lines; update the parser"
    else
      patterns;

  # Expand a workspace glob (e.g. "apps/*") into concrete member dirs
  # relative to the repo root.  Only trailing "*" globs are supported —
  # that's all pnpm-workspace.yaml uses here.  Literal patterns (e.g.
  # "ui-tui") pass through unchanged.
  expandWorkspace =
    pattern:
    let
      parts = lib.splitString "/" pattern;
    in
    if lib.last parts == "*" then
      let
        parent = lib.concatStringsSep "/" (lib.init parts);
        entries = builtins.readDir (repoRoot + "/${parent}");
        dirs = lib.filterAttrs (_: t: t == "directory") entries;
      in
      map (d: "${parent}/${d}") (builtins.attrNames dirs)
    else
      [ pattern ];

  # All workspace member directories (relative paths), filtered to those
  # that actually carry a package.json — a glob like apps/* may match a
  # dir that isn't really a package.
  workspaceMemberDirs = builtins.filter (d: builtins.pathExists (repoRoot + "/${d}/package.json")) (
    lib.concatMap expandWorkspace workspacePatterns
  );

  # Top-level directory of each workspace member, deduplicated.  Used to
  # exclude JS/TS workspace trees from the Python source filter.  E.g.
  # apps/desktop + apps/shared + ui-tui + web → [ "apps" "ui-tui" "web" ].
  jsWorkspaceTopDirs = lib.unique (
    map (d: builtins.head (lib.splitString "/" d)) workspaceMemberDirs
  );

  # ── Source filters for reducing rebuild scope ──────────────────────
  # Changing a .tsx/.mjs file should NOT trigger a Python venv rebuild,
  # and changing a .py file should NOT trigger a TUI/Web/Desktop rebuild.

  # Python source: everything except JS/TS/docs/infra directories.
  pythonSrc = lib.cleanSourceWith {
    src = repoRoot;
    name = "hermes-python-source";
    filter =
      path: type:
      let
        relPath = lib.removePrefix (toString repoRoot + "/") (toString path);
        components = lib.splitString "/" relPath;
        topComponent = if components == [ ] then "" else builtins.head components;
        excludedDirs =
          # JS/TS workspace directories — derived from the pnpm workspaces
          # so a new workspace member is excluded from the Python source
          # without touching this list.
          jsWorkspaceTopDirs ++ [
            # Documentation
            "docs"
            "website"
            # CI/infra
            "docker"
            ".github"
            # Content/examples
            "infographic"
            "datagen-config-examples"
            # unused packaging infra
            "packaging"
            # Test infrastructure
            "tests"
            # Plan/temp files
            "plans"
            # Nix build definitions (Python build doesn't need these)
            "nix"
            # Skills are shipped via HERMES_BUNDLED_SKILLS /
            # HERMES_OPTIONAL_SKILLS (see hermes-agent.nix), not via the
            # wheel's data_files — setup.py's _data_file_tree returns []
            # for a missing dir, so the wheel builds fine without them.
            # This keeps SKILL.md edits from rebuilding the Python venv.
            "skills"
            "optional-skills"
            # locales/ and optional-mcps/ are bare data dirs (no
            # __init__.py) shipped via symlinks + HERMES_BUNDLED_LOCALES
            # / HERMES_OPTIONAL_MCPS, not via the wheel. Excluding them
            # keeps catalog edits from rebuilding the Python venv.
            "locales"
            "optional-mcps"
          ];
        excludedFiles = [
          # JS root manifests
          "package.json"
          "pnpm-lock.yaml"
          "pnpm-workspace.yaml"
          # Docker files
          "Dockerfile"
          "docker-compose.yml"
          "docker-compose.windows.yml"
          # Nix build definitions — editing the flake shouldn't rebuild
          # the venv.  (Input changes rebuild regardless, via the lock.)
          "flake.nix"
          "flake.lock"
          # Root docs the wheel doesn't consume.  README.md and LICENSE
          # must stay — pyproject.toml references them (readme /
          # license-files).
          "AGENTS.md"
          "CONTRIBUTING.md"
          "SECURITY.md"
          "README.zh-CN.md"
          ".gitignore"
          "setup-hermes.sh"
        ];
      in
      if relPath == "" then
        true
      else if lib.hasPrefix "scripts/build/" relPath && lib.hasSuffix ".mjs" relPath then
        # Frontend recipes belong to their product source filters, not Python.
        false
      else if builtins.elem relPath excludedFiles then
        false
      else if builtins.elem topComponent excludedDirs then
        false
      else
        true;
  };

  # Common pnpm workspace resolution files needed by all pnpm builds.
  # A frozen install requires every workspace package.json to match its
  # lockfile importer, and pnpm-workspace.yaml carries the overrides and
  # settings the lockfile was resolved with.  Discovered from
  # pnpm-workspace.yaml — root manifests + every member's package.json.
  npmWorkspaceFiles = lib.fileset.unions (
    [
      (repoRoot + "/package.json")
      (repoRoot + "/pnpm-lock.yaml")
      (repoRoot + "/pnpm-workspace.yaml")
    ]
    ++ map (d: repoRoot + "/${d}/package.json") workspaceMemberDirs
  );

  # pnpm deps source: just what fetchPnpmDeps needs (root manifests +
  # workspace member package.jsons).  Much smaller than the full repo,
  # so changing source files won't invalidate the pnpmDeps derivation.
  pnpmDepsSrc = lib.fileset.toSource {
    root = repoRoot;
    fileset = npmWorkspaceFiles;
  };

  # The pnpm store for the whole lockfile, shared by all members; each
  # build installs only its own slice of it.  nixpkgs has no hashless pnpm
  # importer, so this is a fixed-output derivation pinned by
  # nix/pnpm-deps-hash in the pinned source.
  pnpmDeps = fetchPnpmDeps {
    pname = "hermes-agent";
    src = pnpmDepsSrc;
    inherit pnpm;
    # pnpm >= 11 keeps the store index in SQLite, which only fetcher
    # version 4 dumps reproducibly.
    fetcherVersion = 4;
    # fetchPnpmDeps passes --registry="$NIX_NPM_REGISTRY", which is empty
    # unless the Nix daemon sets it; pnpm 12 takes an empty registry
    # literally and hangs retrying relative URLs.
    # pnpm checks the root engines.node (engineStrict) against the node on
    # PATH, where fetchPnpmDeps puts nixpkgs' node first: install with the
    # pinned node every build uses.
    prePnpmInstall = ''
      export NIX_NPM_REGISTRY=''${NIX_NPM_REGISTRY:-https://registry.npmjs.org/}
      export PATH=${pmNode}/bin:$PATH
    '';
    # Ours: upstream computes nix/pnpm-deps-hash on x86_64-linux CI; on
    # aarch64-darwin pnpm 12's fetchPnpmDeps store produces a different hash.
    # Keep upstream's hash on Linux so nebula matches upstream CI.
    hash =
      if stdenv.hostPlatform.isDarwin then
        "sha256-W5V/4xsKZKolR2MQL5GN9GBa7844IPNmKVTTcLaZnvI="
      else
        lib.fileContents (repoRoot + "/nix/pnpm-deps-hash");
  };

  # Build a per-package pnpm source: workspace resolution files + the
  # package's own directory tree(s).  Source ROOT is always the repo
  # root, preserving the workspace layout that pnpmConfigHook expects.
  # Callers pass the dirs they need (relative to the repo root), so each
  # package owns its own source scope.
  testFileFilter = lib.fileset.fileFilter (file: lib.hasInfix ".test." file.name) repoRoot;
  mkNpmSrc =
    dirs:
    lib.fileset.toSource {
      root = repoRoot;
      fileset = lib.fileset.difference (lib.fileset.union npmWorkspaceFiles (
        lib.fileset.unions (map (d: repoRoot + "/${d}") dirs)
      )) testFileFilter;
    };

  # Returns a stdenv.mkDerivation with the workspace's pnpm deps installed.

  # `dirs` is the single source of truth for what the package contains:
  # its first entry is the package's own folder (→ packageJsonPath), and
  # all entries scope the filtered src.  Packages that import source from
  # another workspace member (workspace: deps) must list that member's dir
  # too, e.g. apps/desktop depends on apps/shared.
  #
  # Usage:
  #   hermesNpmLib.buildPnpmPackage {
  #     dirs = [ "apps/desktop" "apps/shared" ];
  #     buildPhase = '' ... '';
  #     installPhase = '' ... '';
  #   }
  customBuildPnpmPackage =
    { dirs, ... }@attrs:
    let
      # The package's own folder is the first dir; it carries the
      # package.json that names the derivation.
      folder = builtins.head dirs;

      # Read package.json from the repo (the filtered src is a store path, but we can read the original)
      packageJson = builtins.fromJSON (builtins.readFile (repoRoot + "/${folder}/package.json"));
      defaultPname = packageJson.name or "unknown";
      defaultVersion = packageJson.version or "0.0.0";

      common = {
        inherit pnpmDeps;
        # No sourceRoot — the workspace root (with the single pnpm-lock.yaml)
        # is auto-detected as sourceRoot by nix, so pnpmConfigHook finds
        # the lockfile there.
        src = mkNpmSrc dirs;
        # Only this member and the workspace members it depends on (pnpm
        # always adds the root project's own dependencies). The braces make
        # `...` select dependencies; pnpm reads a bare `./dir...` as that
        # dir alone.
        pnpmWorkspaces = [ "{./${folder}}..." ];
        ELECTRON_SKIP_BINARY_DOWNLOAD = 1;
        passthru = {
          packageJsonPath = "${folder}/package.json";
        };
      };

      # Remove `dirs` from the passed attrs (mkDerivation doesn't need it)
      attrsWithoutDirs = removeAttrs attrs [ "dirs" ];

      finalAttrs =
        common
        // attrsWithoutDirs
        // {
          pname = attrs.pname or defaultPname;
          version = attrs.version or defaultVersion;
          nativeBuildInputs = [
            nodejs
            pnpm
            pnpmConfigHook
          ]
          ++ attrs.nativeBuildInputs or [ ];
        };
    in
    stdenv.mkDerivation finalAttrs;
in
{
  inherit
    pythonSrc
    nodejs
    pnpm
    pnpmDeps
    ;

  buildPnpmPackage = customBuildPnpmPackage;
}
