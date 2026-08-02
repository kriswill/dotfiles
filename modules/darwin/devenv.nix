# devenv (devenv.sh) — per-project Nix dev environments. Universal; twin of
# modules/nixos/devenv.nix.
#
# cd auto-activation comes from devenv 2.1's native shell hook
# (`eval "$(devenv hook zsh)"` in home/zsh/.config/zsh/integrations.zsh, trust
# per project via `devenv allow`) — NOT from direnv. Deliberately so: devenv's
# direnvrc ("adapted from nix-direnv") redefines nix-direnv helpers
# (_nix_direnv_preflight, _nix_export_or_unset, _nix_import_env) with
# different bodies, so dropping it into ~/.config/direnv/lib beside
# nix-direnv.sh would let whichever file sorts last silently corrupt the
# other's `use flake`/`use devenv`. The native hook needs no .envrc at all.
{
  flake.modules.darwin.devenv =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.devenv ];
    };
}
