# devenv (devenv.sh) — per-project Nix dev environments. Universal; twin of
# modules/darwin/devenv.nix (see there for why cd-activation uses devenv 2.1's
# native `devenv hook zsh` from the stow integrations.zsh instead of direnv).
{
  flake.modules.nixos.devenv =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.devenv ];
    };
}
