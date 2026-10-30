{
  description = "hermes-agent — Nous Research's Hermes Agent (CLI + gateway) and a single-owner NixOS module, from a trimmed copy of upstream's nix/";

  inputs = {
    # The source tree the copied nix/ builds. Pinned to a release tag:
    # upstream rates Nix "Tier 2", so main may break at any commit. Bumping
    # the tag means porting upstream's nix/ changes since the last one and
    # re-locking the inputs below to that tag's flake.lock (see README.md).
    # Keep `version` in nix/packages.nix in step with the tag.
    hermes-agent-src = {
      url = "github:NousResearch/hermes-agent/v0.22.5";
      flake = false;
    };

    # Locked to the revs in the tag's own flake.lock, so the package is the
    # derivation upstream tested. nixpkgs in particular must not follow a
    # newer one yet: the patchelf 0.19.2 in the root's nixpkgs (2026-10-23)
    # corrupts the prebuilt node from pm/lock.json (NixOS/patchelf#674), and
    # node then segfaults during the TUI build.
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
      # The module is NixOS-only, and nebula is the one consumer.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        ./nix/packages.nix
        ./nix/nixosModules.nix
      ];
    };
}
