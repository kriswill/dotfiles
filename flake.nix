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
    home-manager = {
      url = "github:nix-community/home-manager";
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
  };
}
