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
      # We own nixpkgs (below); make snowglobe follow it so there's a single
      # nixpkgs in the store and we control the rev (e.g. to pull kernel 7.1).
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
      # inputs.pre-commit-hooks = "";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # tomato — Rust CLI to get/set TOML values preserving comments + formatting
    # (built on toml_edit). Not a flake; built via rustPlatform in packages/tomato.nix
    # and exposed as pkgs.tomato. Used by the Hyprland gaps-toggle to flip Noctalia's
    # [shell.screen_corners].enabled.
    tomato = {
      url = "github:ceejbot/tomato";
      flake = false;
    };
    import-tree.follows = "snowglobe-lib/import-tree";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
