{
  description = "Kris' Apple Nix Configuration";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";
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
    # ccglass lives in its own flake (./flakes/ccglass) — a relative-path input, so one
    # git tree serves both and extracting it to a separate repo later is just a URL swap.
    ccglass = {
      url = "./flakes/ccglass";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    # apple-container — Apple's native macOS container CLI, repackaged from its signed
    # .pkg. Same relative-path sub-flake pattern as ccglass.
    apple-container = {
      url = "./flakes/apple-container";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };
}
