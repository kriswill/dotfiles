# Exposes the nixpkgs lib extended with this repo's pure helpers
# (`mkProgramOption`, `kanagawa`) as a top-level option, so both the darwin and
# home-manager evaluations can receive it via specialArgs / extraSpecialArgs.
{ lib, inputs, ... }:
{
  options.kriswill.lib = lib.mkOption {
    type = lib.types.raw;
    readOnly = true;
    description = "nixpkgs lib extended with repo helpers (mkProgramOption, kanagawa).";
  };

  config.kriswill.lib = inputs.nixpkgs.lib.extend (final: _: import ../lib { lib = final; });
}
