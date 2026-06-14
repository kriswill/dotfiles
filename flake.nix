{
  description = "my NixOS configurations";

  # Dendritic layout: flake-parts wraps `import-tree ./modules`, so every `.nix`
  # file under `modules/` is a flake-parts module (auto-discovered). import-tree
  # skips any path containing `/_`, so host-specific plain NixOS modules live in
  # `modules/hosts/_nebula/` and are pulled in by explicit `imports`. Outputs are
  # exposed through flake-parts (`flake.nixosConfigurations`, `flake.overlays`,
  # `flake.modules.nixos.*`, per-system `packages`).
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

    import-tree.follows = "snowglobe-lib/import-tree";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
