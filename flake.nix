{
  description = "Kris' Nix configurations — macOS (nix-darwin) + NixOS";

  # hyprland.cachix.org is configured where it's actually trusted — nebula's
  # daemon (modules/hosts/nebula/hyprland.nix) and CI (extra-nix-config in
  # ci.yml) — not via flake nixConfig, which untrusted clients just warn about.

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
    # okf ships from FlakeHub (kriswill/okflight, public); "0" tracks the 0.x
    # release series — `nix flake update okf` moves to the newest release.
    # If it ever goes private: FlakeHub supports private flakes (netrc auth).
    okf = {
      url = "https://flakehub.com/f/kriswill/okflight/0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    codebase-memory-mcp = {
      url = "github:kriswill/codebase-memory-mcp/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ### nixos
    # Determinate Nix on nebula (replaces snowglobe-factory's Lix default; the Macs
    # are already on Determinate, installer-managed). Deliberately NO nixpkgs
    # follows: upstream recommends against it (FlakeHub cache misses).
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    snowglobe-factory = {
      url = "github:kriswill/snowglobe-factory/unstable";
      # url = "git+file:///home/k/src/codeberg/kriswill/snowglobe-factory";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        import-tree.follows = "import-tree";
        sops-nix.follows = "sops-nix";
        nixos-hardware.follows = "nixos-hardware";
        # Prune Lix entirely — we run Determinate Nix everywhere (see above),
        # and Lix-written lock entries break CppNix lock verification.
        lix.follows = "";
        lix-module.follows = "";
      };
    };
    # Explicit sops-nix (snowglobe-factory follows it, above): also provides
    # darwinModules.sops for secrets on the macOS hosts.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Deliberately NO nixpkgs follows (unlike everything else here): following
    # rebuilds the whole hypr* stack against our nixpkgs, which only matches
    # hyprland.cachix.org when our rev happens to be
    # drv-equivalent to their lock's. Un-followed, the drvs are byte-identical
    # to upstream CI's — guaranteed cache hits. Costs a second nixpkgs eval.
    # Consumed via inputs.hyprland.packages (modules/hosts/nebula/hyprland.nix),
    # NOT the overlays — overlay builds would rebuild against our nixpkgs and
    # defeat the cache anyway.
    hyprland.url = "github:hyprwm/Hyprland";
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell/v5.0.0-beta.8";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # herdr pinned to the upstream v0.8.0 stable tag (the repo ships its own
    # flake; no binary cache, builds from source) for the CSI 14t/16t
    # pixel-size fix (herdrdev/herdr#835) that 0.7.5 lacks — required for
    # image rendering (fastfetch/yazi) inside herdr panes, together with
    # `experimental.kitty_graphics = true` in the stow config.toml. See
    # docs/fastfetch.md. Drop back to nixpkgs' herdr once nixos-unstable
    # ships >= 0.8.0. (rust-overlay is left unfollowed — we don't carry one.)
    herdr = {
      url = "github:herdrdev/herdr/v0.8.0";
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
