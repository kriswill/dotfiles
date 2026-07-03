# nh (Nix Helper) — nix-darwin has no programs.nh module; just install it.
# The nrs/nrt rebuild aliases in core.nix invoke it via lib.getExe.
{
  flake.modules.darwin.nh =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.nh ];
    };
}
