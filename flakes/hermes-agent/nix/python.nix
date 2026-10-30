# nix/python.nix — uv2nix virtual environment builder
#
# Ours: dropped the editable venv, which only the dev shell used (it is
# rooted at the live checkout).
{
  lib,
  callPackage,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
  stdenv,
  # Filtered Python source (see lib.nix pythonSrc) — keeps JS/docs/skills
  # edits from invalidating the venv derivation.
  pythonSrc,
  dependency-groups ? [ "all" ],
}:
let
  # The interpreter family comes from pm/lock.json (pythonLock.nix owns the
  # selection); every override below must be built for THAT interpreter.
  pythonLock = callPackage ./pythonLock.nix { };
  python = pythonLock.interpreter;
  pythonPackages = python.pkgs;

  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = pythonSrc; };
  hacks = callPackage pyproject-nix.build.hacks { };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  isAarch64Darwin = stdenv.hostPlatform.system == "aarch64-darwin";

  # Keep the workspace locked through uv2nix, but supply the local voice stack
  # from nixpkgs so wheel-only transitive artifacts do not break evaluation.
  mkPrebuiltPassthru = dependencies: {
    inherit dependencies;
    optional-dependencies = { };
    dependency-groups = { };
  };

  mkPrebuiltOverride =
    final: from: dependencies:
    hacks.nixpkgsPrebuilt {
      inherit from;
      prev = {
        nativeBuildInputs = [ final.pyprojectHook ];
        passthru = mkPrebuiltPassthru dependencies;
      };
    };

  # Legacy alibabacloud packages ship only sdists with setup.py/setup.cfg
  # and no pyproject.toml, so setuptools isn't declared as a build dep.
  buildSystemOverrides =
    final: prev:
    builtins.mapAttrs
      (
        name: _:
        prev.${name}.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.setuptools ];
        })
      )
      (
        lib.genAttrs [
          "alibabacloud-credentials-api"
          "alibabacloud-endpoint-util"
          "alibabacloud-gateway-dingtalk"
          "alibabacloud-gateway-spi"
          "alibabacloud-tea"
        ] (_: null)
      )
    // {
      # The locked sdist has no build-system metadata; setup.py imports
      # setuptools and uses CFFI to compile the bundled libolm.
      python-olm = prev.python-olm.overrideAttrs (old: {
        nativeBuildInputs =
          (old.nativeBuildInputs or [ ])
          ++ final.resolveBuildSystem {
            setuptools = [ ];
            cffi = [ ];
          };
      });
      # [kittentts] locks misaki as a git source. uv.lock records no build
      # backend for it, so supply the hatchling its pyproject declares.
      misaki = prev.misaki.overrideAttrs (old: {
        nativeBuildInputs =
          (old.nativeBuildInputs or [ ])
          ++ final.resolveBuildSystem {
            hatchling = [ ];
          };
      });
    };

  pythonPackageOverrides =
    final: _prev:
    if isAarch64Darwin then
      {
        numpy = mkPrebuiltOverride final pythonPackages.numpy { };

        pyarrow = mkPrebuiltOverride final pythonPackages.pyarrow { };

        av = mkPrebuiltOverride final pythonPackages.av { };

        humanfriendly = mkPrebuiltOverride final pythonPackages.humanfriendly { };

        coloredlogs = mkPrebuiltOverride final pythonPackages.coloredlogs {
          humanfriendly = [ ];
        };

        onnxruntime = mkPrebuiltOverride final pythonPackages.onnxruntime {
          coloredlogs = [ ];
          numpy = [ ];
          packaging = [ ];
        };

        ctranslate2 = mkPrebuiltOverride final pythonPackages.ctranslate2 {
          numpy = [ ];
          pyyaml = [ ];
        };

        faster-whisper = mkPrebuiltOverride final pythonPackages.faster-whisper {
          av = [ ];
          ctranslate2 = [ ];
          huggingface-hub = [ ];
          onnxruntime = [ ];
          tokenizers = [ ];
          tqdm = [ ];
        };
      }
    else
      { };

  pythonSet =
    (callPackage pyproject-nix.build.packages {
      inherit python;
    }).overrideScope
      (
        lib.composeManyExtensions [
          pyproject-build-systems.overlays.default
          overlay
          buildSystemOverrides
          pythonPackageOverrides
          # ``setup.py`` permits wheel/sdist creation only from the sealed
          # Hermes derivation. This is deliberately a derivation environment
          # variable, not a devShell variable: ``nix develop -c uv build``
          # must remain blocked.
          (final: prev: {
            hermes-agent = prev.hermes-agent.overrideAttrs (_old: {
              HERMES_NIX_BUILD = "1";
            });
          })
        ]
      );
in
{
  inherit python;

  venv = pythonSet.mkVirtualEnv "hermes-agent-env" {
    hermes-agent = dependency-groups;
  };
}
