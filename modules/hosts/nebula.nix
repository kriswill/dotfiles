# nebula — AMD CPU, NVIDIA GPU, UEFI desktop.
#
# Registers into the `configurations.nixos` registry (realised by
# `modules/nixos.nix` through snowglobe-lib's `mkNixosHost`). The host module
# imports every shared `flake.modules.nixos.*` feature plus the host-specific
# plain modules under `_nebula/` — that directory is skipped by import-tree
# (its path contains `/_`), so it is pulled in here by explicit `imports`.
{ config, ... }:
{
  configurations.nixos.nebula = {
    hostname = "nebula";
    cpu-vendor = "amd";
    gpu-vendors = [ "nvidia" ];
    firmware = "UEFI";
    isVM = false;
    stateVersion = "26.05";

    module = {
      imports = (builtins.attrValues config.flake.modules.nixos) ++ [
        ./_nebula/configuration.nix
        ./_nebula/disko.nix
        ./_nebula/hardware-configuration.nix
        ./_nebula/console-quiet.nix
        ./_nebula/ly.nix
        ./_nebula/sudo-1password.nix
        ./_nebula/windows-mount.nix
        ./_nebula/flatpak-repo-network.nix
        ./_nebula/users/k
      ];

      # Previously applied via the `nixosModules.default` import-tree wrapper;
      # re-applied here so helium/wowup/hyprland resolve through our overlays.
      nixpkgs.overlays = builtins.attrValues config.flake.overlays;

      # mkNixosHost only sets `sops.defaultSopsFile` when given a `configDir`,
      # which we don't pass — so point it at the host secrets explicitly.
      sops.defaultSopsFile = ./_nebula/secrets.yaml;
    };
  };
}
