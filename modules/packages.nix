# Custom derivations exposed as `packages.<system>.*` (e.g. `nix build .#helium`).
# The default `pkgs` flake-parts hands to perSystem lacks our overlays and
# allowUnfree, so override `_module.args.pkgs` (the canonical flake-parts overlay
# pattern). The actual derivations live in `packages/` and are reused by the
# `my-packages` overlay too.
{ config, inputs, ... }:
{
  perSystem =
    { system, pkgs, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        # closes over the top-level flake-parts `config`
        overlays = builtins.attrValues config.flake.overlays;
      };

      packages = import ../packages { inherit pkgs inputs; };
    };
}
