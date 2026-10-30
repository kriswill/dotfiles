# nix/packages.nix — Hermes Agent package built with uv2nix
#
# Ours: upstream's nix/packages.nix cut down to the one package the module
# runs. Upstream's files live in its source tree and reach that tree through
# `./..`. These copies live here, so the source arrives as the
# `hermes-agent-src` input and every file takes it as `hermesSrc`, a path
# value at the root of that tree: `../pm/lock.json` there is
# `hermesSrc + "/pm/lock.json"` here. It must be a path, not the input's
# outPath string, because lib.fileset only accepts paths and because copying a
# path into the store is what gives each filtered source the same store path
# upstream gets. Discarding the context is safe: hermesSrc is never
# interpolated as a string, only copied as a path, and the input's store path
# is readable under pure evaluation. A scope supplies it, so the nested
# callPackage calls receive it without being passed it by hand.
#
# Dropped: the sandbox, desktop, tui, web, messaging, node-gyp and
# update-npm-lockfile outputs and the per-tool pm-* packages. The TUI and web
# bundles still build as passthru of the package.
{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      src = inputs.hermes-agent-src;
      hermesSrc = /. + builtins.unsafeDiscardStringContext src.outPath;
      scope = lib.makeScope pkgs.newScope (_: {
        inherit hermesSrc;
      });

      # pm/lock.json translated into derivations — one per tool package
      # with an artifact for this system. The lockfile carries resolved
      # urls + hashes, so nix consumes it as pure data. callPackage adds
      # .override/.overrideDerivation to the returned SET; keep only the
      # real derivations.
      pmPackages = lib.filterAttrs (_: lib.isDerivation) (scope.callPackage ./pm-packages.nix { });

      # Ours: the stamp's provenance is the pinned source, not this flake.
      # Upstream leaves `version` at 0.0.0, which is what `hermes --version`
      # then reports; keep it in step with the tag in flake.nix.
      minimal = scope.callPackage ./hermes-agent.nix {
        inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
        inherit pmPackages;
        inherit (src) rev lastModified;
        version = "0.22.5";
      };

      # All platform-portable optional integrations pre-built.
      full = minimal.override {
        extraDependencyGroups = [
          "anthropic"
          "azure-identity"
          "bedrock"
          "daytona"
          "dingtalk"
          "edge-tts"
          "exa"
          "fal"
          "feishu"
          "firecrawl"
          "messaging"
          "modal"
          "parallel-web"
          "tts-premium"
          "vercel"
          "voice"
        ]
        # matrix is Linux-only (oqs/liboqs lacks aarch64-darwin wheels).
        ++ lib.optionals pkgs.stdenv.isLinux [ "matrix" ];
      };
    in
    {
      packages = {
        hermes-agent = full;
        default = config.packages.hermes-agent;
      };
    };
}
