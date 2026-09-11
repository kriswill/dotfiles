# devenv (devenv.sh) — per-project Nix dev environments. Universal; twin of
# modules/darwin/devenv.nix (see there for why cd-activation uses devenv 2.1's
# native `devenv hook zsh` from the stow integrations.zsh instead of direnv).
{
  flake.modules.nixos.devenv =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.devenv ];

      # Upstream caches for devenv's dependency crates; see the darwin twin.
      nix.settings = {
        extra-substituters = [
          "https://devenv.cachix.org"
          "https://cachix.cachix.org"
        ];
        extra-trusted-public-keys = [
          "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
          "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
        ];
      };
    };
}
