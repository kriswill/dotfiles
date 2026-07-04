{
  description = "Kris' Nix configurations — macOS (nix-darwin) + NixOS";

  # Dendritic layout: flake-parts wraps `import-tree ./modules`, so every `.nix`
  # file under `modules/` is a flake-parts module (auto-discovered). Host config
  # lives as first-class files under `modules/hosts/` merging into
  # `configurations.{darwin,nixos}.<host>.module`. Outputs are exposed through
  # flake-parts (`flake.darwinConfigurations`, `flake.nixosConfigurations`,
  # `flake.overlays`, `flake.modules.{darwin,nixos}.*`, per-system `packages`).
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    # nixos-unstable rather than nixpkgs-unstable: the same package set gated on
    # the NixOS test suite — safe for darwin (it lags a few days), required
    # regression cover for nebula.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";

    ### darwin
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    faster-piper-yazi = {
      url = "github:alberti42/faster-piper.yazi";
      flake = false;
    };
    yazi-plugins = {
      url = "github:yazi-rs/plugins";
      flake = false;
    };
    ccglass = {
      url = "./flakes/ccglass";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    apple-container = {
      url = "./flakes/apple-container";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    okf = {
      url = "./flakes/okf";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    codebase-memory-mcp = {
      url = "github:kriswill/codebase-memory-mcp/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ### nixos
    # Determinate Nix on nebula (replaces snowglobe-lib's Lix default; the Macs
    # are already on Determinate, installer-managed). Deliberately NO nixpkgs
    # follows: upstream recommends against it (FlakeHub cache misses).
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    snowglobe-lib = {
      # Host builder (mkNixosHost), snowglobe-lib.profiles/desktop options.
      url = "git+https://codeberg.org/earthgman/snowglobe-lib?ref=unstable";
      # We own nixpkgs (above); make snowglobe follow it so there's a single
      # nixpkgs in the store and we control the rev (e.g. to pull kernel 7.1).
      inputs = {
        nixpkgs.follows = "nixpkgs";
        import-tree.follows = "import-tree";
        sops-nix.follows = "sops-nix";
      };
    };
    # Explicit sops-nix (snowglobe-lib follows it, above): also provides
    # darwinModules.sops for secrets on the macOS hosts.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # tomato — Rust CLI to get/set TOML values preserving comments + formatting
    # (built on toml_edit). Not a flake; built via rustPlatform in pkgs/tomato.nix
    # and exposed as pkgs.tomato. Used by the Hyprland gaps-toggle to flip
    # Noctalia's [shell.screen_corners].enabled.
    tomato = {
      url = "github:ceejbot/tomato";
      flake = false;
    };
  };
}
