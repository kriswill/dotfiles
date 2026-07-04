# Determinate Nix replaces snowglobe-lib's Lix default: snowglobe sets
# nix.package at priority 1337 (setDefault); the determinate module's plain
# assignment wins — no fork, no mkForce. Its determinate-nixd owns
# /etc/nix/nix.conf and includes the NixOS-generated settings via
# /etc/nix/nix.custom.conf, so snowglobe's nix.settings survive.
# Why we left Lix: no Nix ≥2.26 relative-path input locking (lix#641),
# which made the ./flakes/* sub-flake inputs churn flake.lock on every rebuild.
{ inputs, ... }:
{
  flake.modules.nixos.determinate = {
    imports = [ inputs.determinate.nixosModules.default ];

    nix.settings = {
      extra-substituters = [ "https://install.determinate.systems" ];
      extra-trusted-public-keys = [
        "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      ];
    };

    # Keep `nix run nixpkgs#…` on this flake's nixpkgs; without this,
    # determinate pins the registry to FlakeHub's nixpkgs-weekly tarball.
    nix.registry.nixpkgs.flake = inputs.nixpkgs;
  };
}
