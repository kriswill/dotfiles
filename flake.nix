{
  description = "my NixOS configurations";

  # Dendritic layout: flake-parts wraps `import-tree ./modules`, so every `.nix`
  # file under `modules/` is a flake-parts module (auto-discovered). Host-specific
  # config lives as first-class files under `modules/hosts/nebula/`, each merging
  # into the host's `configurations.nixos.nebula.module` — so no path needs to be
  # excluded from the scan. Outputs are exposed through flake-parts
  # (`flake.nixosConfigurations`, `flake.overlays`, `flake.modules.nixos.*`,
  # per-system `packages`).
  inputs = {
    snowglobe-lib = {
      # url = "git+https://codeberg.org/earthgman/snowglobe-lib";
      url = "git+https://codeberg.org/earthgman/snowglobe-lib?ref=unstable";
      # Be sure to also uncomment this if you use your own nixpkgs input to avoid duplicate nixpkgs repos in the store.
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.follows = "snowglobe-lib/nixpkgs";
    # comment above and uncomment below to pin your own nixpkgs revision in the flake.lock.
    # Could cause instabilities, use at your own risk.
    # nixpkgs = {
    #   url = "github:NixOS/nixpkgs/nixos-unstable";
    # };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
      # inputs.pre-commit-hooks = "";
    };
    # Noctalia shell (Wayland desktop shell + launcher)
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.follows = "snowglobe-lib/import-tree";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
