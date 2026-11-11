{
  description = "hermes-agent — Nous Research's Hermes Agent (CLI + gateway) and single-owner NixOS and nix-darwin modules, from a trimmed copy of upstream's nix/";

  inputs = {
    # The source tree the copied nix/ builds. Pinned to a release tag:
    # upstream rates Nix "Tier 2", so main may break at any commit. Bumping
    # the tag means porting upstream's nix/ changes since the last one and
    # re-locking the inputs below to that tag's flake.lock (see README.md).
    # Keep `version` in nix/packages.nix in step with the tag.
    hermes-agent-src = {
      url = "github:NousResearch/hermes-agent/v0.23.0";
      flake = false;
    };

    # Locked to the revs in the tag's own flake.lock, so the package is the
    # derivation upstream tested. Since v0.23.0 nix/pm-packages.nix patches
    # patchelf itself (NixOS/patchelf#674 broke the prebuilt node), so
    # following the root's nixpkgs is possible again but untried.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Upstream's own systems. nebula consumes the NixOS module, the macs
      # the nix-darwin one.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      imports = [
        ./nix/packages.nix
        ./nix/nixosModules.nix
        ./nix/darwinModules.nix
      ];
    };
}
