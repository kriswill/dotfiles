# nix/hermes-agent.nix — Overridable Hermes Agent package
#
# callPackage auto-wires nixpkgs args; flake inputs are passed explicitly.
# Users override via:
#   pkgs.hermes-agent.override { extraPythonPackages = [...]; }
#   pkgs.hermes-agent.override { extraDependencyGroups = [ "voice" ]; }
#
# Ours: the source tree is hermesSrc (see packages.nix). Dropped the desktop
# app (Electron), the dev shell passthru (editable venv, pm, devDeps) and the
# npm-lockfile-fix input, which only lib.nix's update script used.
{
  lib,
  stdenv,
  makeWrapper,
  writeText,
  callPackage,
  git,
  openssh,

  # linux-only deps
  wl-clipboard,
  xclip,

  # Flake inputs — passed explicitly by packages.nix
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
  # nix/pm-packages.nix output: every pm/lock.json pin as a derivation.
  pmPackages,
  # The pinned upstream source tree, from the scope in packages.nix.
  hermesSrc,
  # Locked git revision of the flake source — embedded so banner.py can
  # check for updates without needing a local .git directory. Null for
  # impure / dirty builds where flakes can't determine a rev.
  rev ? null,
  branch ? null,
  dirty ? false,
  lastModified ? null,
  # Overridable parameters
  version ? "0.0.0",
  distance ? 0,
  extraPythonPackages ? [ ],
  extraDependencyGroups ? [ ],
}:
let
  # One owner (pythonLock.nix) reads pm/lock.json and selects the matching
  # nixpkgs interpreter. Everything Python-shaped below derives from it.
  pythonLock = callPackage ./pythonLock.nix { };
  python = pythonLock.interpreter;

  # Install stamp values — written to install-stamp.json so the Python
  # runtime (CLI, TUI) reads one file instead of env vars or .git probes.
  stampDistance =
    if builtins.isInt distance && distance >= 0 then
      distance
    else
      throw "distance must be a non-negative integer";
  stampDisplayVersion =
    if stampDistance > 0 && rev != null then
      "${version}+${toString stampDistance}.g${builtins.substring 0 7 rev}"
    else if stampDistance > 0 then
      throw "a non-zero distance requires an exact revision"
    else
      version;

  # CLI and Electron consume the same provenance and update owner.
  installStampFile = writeText "hermes-install-stamp.json" (
    builtins.toJSON {
      schemaVersion = 2;
      commit = rev;
      commitDate = lastModified;
      inherit branch dirty;
      builtAt = null;
      baseVersion = version;
      displayVersion = stampDisplayVersion;
      distance = stampDistance;
      source = "nix";
      distribution = "nix";
      pmRuntime = toString pmRuntime;
      updateMechanism = "external";
      payload = "bootstrap";
      tag = null;
    }
  );

  mkHermesVenv =
    extraDependencyGroups:
    callPackage ./python.nix {
      inherit uv2nix pyproject-nix pyproject-build-systems;
      pythonSrc = hermesNpmLib.pythonSrc;
      dependency-groups = [ "all" ] ++ extraDependencyGroups;
    };

  hermesVenv = (mkHermesVenv extraDependencyGroups).venv;

  pmRuntime = callPackage ./pm-runtime.nix {
    inherit uv2nix pyproject-nix pyproject-build-systems;
  };

  # Icons render on the runtime venv: Pillow and resvg-py are core dependencies.
  generatedIcons = callPackage ./icons.nix {
    inherit (mkHermesVenv [ ]) venv;
  };

  hermesNpmLib = callPackage ./lib.nix {
    inherit pmPackages;
  };

  hermesTui = callPackage ./tui.nix {
    inherit hermesNpmLib;
  };

  hermesWeb = callPackage ./web.nix {
    inherit hermesNpmLib generatedIcons;
  };

  bundledSkills = lib.cleanSourceWith {
    src = hermesSrc + "/skills";
    filter = path: _type: !(lib.hasInfix "/index-cache/" path) && !(lib.hasInfix "/__pycache__/" path);
  };

  # Optional skills are NOT in the wheel (pythonSrc excludes them, see
  # lib.nix) — the wrapper exposes them via HERMES_OPTIONAL_SKILLS, the
  # same mechanism Homebrew packaging uses.
  bundledOptionalSkills = lib.cleanSourceWith {
    src = hermesSrc + "/optional-skills";
    filter = path: _type: !(lib.hasInfix "/index-cache/" path) && !(lib.hasInfix "/__pycache__/" path);
  };

  # Import bundled plugins (memory, context_engine, platforms/*).  Keeping
  # them out of the Python site-packages keeps import semantics identical
  # to a dev checkout — the loader reads them from HERMES_BUNDLED_PLUGINS.
  bundledPlugins = lib.cleanSourceWith {
    src = hermesSrc + "/plugins";
    filter = path: _type: !(lib.hasInfix "/__pycache__/" path);
  };

  # i18n locale catalogs (locales/*.yaml). Shipped into the store and pointed
  # at by HERMES_BUNDLED_LOCALES so the wrapped binary always resolves human
  # strings instead of raw i18n keys (#23943 / #27632 / #35374).
  bundledLocales = lib.cleanSource (hermesSrc + "/locales");

  # Shipped MCP catalog (optional-mcps/<name>/manifest.yaml). Same bare-data-dir
  # case as locales: not a Python package, so it's symlinked into the store and
  # exposed via HERMES_OPTIONAL_MCPS.
  bundledOptionalMcps = lib.cleanSourceWith {
    src = hermesSrc + "/optional-mcps";
    filter = path: _type: !(lib.hasInfix "/__pycache__/" path);
  };

  # Ours: PM receipts must describe the actual pinned artifacts, not
  # nixpkgs executables falsely labelled with PM's archive hashes.
  inherit (pmPackages) ripgrep ffmpeg;

  runtimeDeps = [
    hermesNpmLib.nodejs
    ripgrep
    git
    openssh
    ffmpeg
  ]
  ++ lib.optionals stdenv.isLinux [
    wl-clipboard
    xclip
  ];

  runtimePath = lib.makeBinPath runtimeDeps;

  sitePackagesPath = python.sitePackages;

  # Only the offline assembler's import closure. A frontend or catalog edit
  # must not change this source, and no build output is read during evaluation.
  agentBuilderSrc = lib.fileset.toSource {
    root = hermesSrc;
    fileset = lib.fileset.unions [
      (hermesSrc + "/scripts/build/agent.py")
      (hermesSrc + "/scripts/build/inputs.py")
      (hermesSrc + "/scripts/build/launchers.py")
    ];
  };

  agentInputsFile = writeText "hermes-agent-inputs.json" (
    builtins.toJSON {
      project = "${hermesSrc + "/pyproject.toml"}";
      code = "${hermesVenv}/${sitePackagesPath}";
      repo = "share/hermes-agent";
      placement = "references";
      target = "${if stdenv.hostPlatform.isDarwin then "darwin" else "linux"}-${
        if stdenv.hostPlatform.isAarch64 then "arm64" else "x64"
      }";
      python = "${hermesVenv}/bin/python3";
      site_packages = "${hermesVenv}/${sitePackagesPath}";
      environment = toString hermesVenv;
      pm_runtime = toString pmRuntime;
      command_dir = "${hermesVenv}/bin";
      resources = {
        skills = toString bundledSkills;
        optional-skills = toString bundledOptionalSkills;
        plugins = toString bundledPlugins;
        locales = toString bundledLocales;
        optional-mcps = toString bundledOptionalMcps;
      };
      frontends = {
        tui = "${hermesTui}/lib/hermes-tui";
        web = toString hermesWeb;
      };
      ref = if dirty then null else rev;
      stamp = toString installStampFile;
      env = {
        HERMES_NODE = lib.getExe hermesNpmLib.nodejs;
      }
      // lib.optionalAttrs (rev != null && !dirty) {
        HERMES_REVISION = rev;
      };
    }
  );

  # Walk propagatedBuildInputs to include transitive Python deps in PYTHONPATH.
  # Without this, a plugin listing e.g. requests as a dep would fail at runtime
  # if requests isn't already in the sealed uv2nix venv.
  allExtraPythonPackages = python.pkgs.requiredPythonModules extraPythonPackages;

  pythonPath = lib.makeSearchPath sitePackagesPath allExtraPythonPackages;

  checkPackageCollisions = ''
    import pathlib, sys, re

    def canonical(name):
        return re.sub(r'[-_.]+', '-', name).lower()

    # Collect core venv package names
    core = set()
    venv_sp = pathlib.Path('${hermesVenv}/${sitePackagesPath}')
    for di in venv_sp.glob('*.dist-info'):
        meta = di / 'METADATA'
        if meta.exists():
            for line in meta.read_text().splitlines():
                if line.startswith('Name:'):
                    core.add(canonical(line.split(':', 1)[1].strip()))
                    break

    # Check each extra package for collisions
    extras_dirs = [${lib.concatMapStringsSep ", " (p: "'${toString p}'") allExtraPythonPackages}]
    for edir in extras_dirs:
        sp = pathlib.Path(edir) / '${sitePackagesPath}'
        if not sp.exists():
            continue
        for di in sp.glob('*.dist-info'):
            meta = di / 'METADATA'
            if not meta.exists():
                continue
            for line in meta.read_text().splitlines():
                if line.startswith('Name:'):
                    pkg = canonical(line.split(':', 1)[1].strip())
                    if pkg in core:
                        print(f'ERROR: plugin package \"{pkg}\" collides with a package in hermes sealed venv', file=sys.stderr)
                        print(f'  from: {di}', file=sys.stderr)
                        print(f'  Remove this dependency from extraPythonPackages.', file=sys.stderr)
                        sys.exit(1)
                    break

    print('No collisions found.')
  '';
in
stdenv.mkDerivation {
  pname = "hermes-agent";
  inherit version;

  dontUnpack = true;
  dontBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    # uv2nix owns Python code and dependencies. The shared assembler only
    # links resources and emits the derived command/environment description.
    PYTHONPATH=${agentBuilderSrc} ${python}/bin/python3 -m scripts.build.agent \
      --inputs ${agentInputsFile} --out "$out"

    # Ours: publish a sealed PM store for the tools actually shipped here.
    # Nix verifies the lock's archive hashes; PM verifies the executable and
    # records the realized tree digest after Nix's ELF/wrapper fixups. Include
    # node/npm so this store does not depend on a user's pre-existing receipts.
    mkdir -p "$out/tools"
    ln -s ${ffmpeg} "$out/tools/ffmpeg"
    ln -s ${ripgrep} "$out/tools/ripgrep"
    ln -s ${hermesNpmLib.nodejs} "$out/tools/node"
    ln -s ${hermesNpmLib.nodejs} "$out/tools/npm"
    PATH="${runtimePath}:$PATH" ${hermesVenv}/bin/python3 - "$out/tools" <<'PY'
    import json, sys
    from pathlib import Path
    from pm.lock import Facts, Lockfile
    from pm.paths import lockfile_path
    from pm.registry import get_package
    from pm.store import current_target, tree_digest

    root = Path(sys.argv[1])
    lock = Lockfile(lockfile_path())
    facts = Facts(root / "facts.json")
    target = current_target()
    for name in ("ffmpeg", "ripgrep", "node", "npm"):
        package = get_package(name)
        entry = root / name
        reason = package.verify(entry, target)
        if reason:
            raise RuntimeError(f"{name}: {reason}")
        artifacts = [a["sha256"] for a in lock.artifacts(name, target)]
        if not artifacts:
            raise RuntimeError(f"{name}: no pinned artifacts for {target}")
        facts.record(name, lock.version(name), name, package.env(entry, target),
                     root, target=target, artifacts=artifacts, digest=tree_digest(entry))
    # PM imports live in the separate venv, not beside the payload manifest.
    # Its supported stamp binding makes this store discoverable there too.
    stamp_path = root.parent / "share/hermes-agent/install-stamp.json"
    stamp = json.loads(stamp_path.read_text())
    stamp["runtimeDir"] = str(root)
    stamp_path.unlink()
    stamp_path.write_text(json.dumps(stamp) + "\n")
    PY

    # Native wrappers retain Nix's PATH/PYTHONPATH policies. Names, executable
    # sources and resource bindings come from the builder, not another table.
    makeAgentWrapper() {
      local source="$1" destination="$2"
      shift 2
      makeWrapper "$source" "$out/$destination" "$@" \
        --suffix PATH : "${runtimePath}" \
        --set-default HERMES_BIN "$out/bin/hermes"${
          lib.optionalString (
            extraPythonPackages != [ ]
          ) " \\\n        --suffix PYTHONPATH : \"${pythonPath}\""
        }
    }
    ${python}/bin/python3 - "$out/command-map.json" > "$TMPDIR/agent-wrappers.sh" <<'PY'
    import json, shlex, sys

    with open(sys.argv[1]) as handle:
        description = json.load(handle)
    env = [arg for key, value in sorted(description["env"].items())
           for arg in ("--set", key, value)]
    for command in description["commands"].values():
        print(shlex.join(["makeAgentWrapper", command["source"], command["destination"], *env]))
    PY
    source "$TMPDIR/agent-wrappers.sh"

    ${lib.optionalString (extraPythonPackages != [ ]) ''
      echo "=== Checking for plugin/core package collisions ==="
      ${hermesVenv}/bin/python3 -c "${checkPackageCollisions}"
      echo "=== No collisions ==="
    ''}

    runHook postInstall
  '';

  passthru = {
    inherit
      hermesTui
      hermesWeb
      hermesNpmLib
      hermesVenv
      agentBuilderSrc
      agentInputsFile
      installStampFile
      pmRuntime
      python
      ;
  };

  meta = with lib; {
    description = "AI agent with advanced tool-calling capabilities";
    homepage = "https://github.com/NousResearch/hermes-agent";
    mainProgram = "hermes";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
