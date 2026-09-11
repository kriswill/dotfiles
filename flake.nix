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
    # dotbar pinned to the nix-flake PR head (tlehman/dotbar#1) while the flake
    # packaging bakes upstream; bump to a tag (or drop the rev) once it merges.
    dotbar = {
      url = "github:tlehman/dotbar/ea59efe59527336206bffc2f1d05b87787568b87";
      inputs.nixpkgs.follows = "nixpkgs";
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
    # herdr from UPSTREAM's v0.9.0 tag, built against ITS OWN locked nixpkgs
    # and rust-overlay (no `follows`): the derivation then only changes when
    # the herdr pin or our patch changes, not on every weekly nixpkgs bump.
    # Our local changes ride as a patch applied by the herdr overlay
    # (overlays/herdr/*.patch, exported with `git format-patch` from the
    # kriswill/herdr `custom` branch) — currently the ANSI tab-bar command
    # entries (ui.tab_bar_right `argv`/`ansi` fields: run e.g. dotbar without
    # a shell and render its SGR-colored output inline; HERDR_TOKEN_* env
    # from workspace metadata with reactive re-runs). On each new upstream
    # tag: rebase `custom`, re-export the patch, bump the tag here, and drop
    # the patch once it lands upstream (herdr-update-check is the reminder).
    # v0.8.2+ is needed for the CSI 14t/16t pixel-size fix (herdrdev/herdr#835)
    # that nixpkgs' 0.7.5 lacks — required for image rendering
    # (fastfetch/yazi) inside herdr panes, together with
    # `experimental.kitty_graphics = true` in the stow config.toml; see
    # docs/fastfetch.md. Upstream has no binary cache; the patched build is
    # cached by our CI on FlakeHub.
    herdr.url = "github:herdrdev/herdr/v0.9.0";
    # devenv from UPSTREAM (pinned commit, NOT a flake input): the devenv
    # overlay applies our patches from overlays/devenv/ to the source and
    # evaluates the patched tree through flake-compat, so it builds with ITS
    # OWN flake.lock (nixpkgs, rust-overlay, cachix, nix) exactly like
    # upstream CI does — every dependency crate then substitutes from
    # devenv.cachix.org (wired in modules/{darwin,nixos}/devenv.nix) and
    # only the patched crates rebuild. Patches (both filed as
    # cachix/devenv#3130) touch the `devenv shell` virtual-terminal mux:
    # terminal-query reply ordering (CPR was answered locally while OSC
    # queries round-tripped to the real terminal, so termenv users like
    # gh/glow got the cursor report first and left the colour reply in the
    # tty buffer for zsh to eat), and kitty graphics passthrough (the VT
    # stores images and answers `a=q`; the renderer mirrors placements onto
    # the real terminal; a probed cell size gives the PTY pixel dimensions and
    # answers `CSI 14 t`) so fastfetch/yazi/icat render inside the shell.
    # Bumping: move the rev, re-export the patches from a rebased branch
    # (`git format-patch --no-signature <upstream>..HEAD`), drop patches as
    # they land. The patched tree is a derivation, so evaluating it is
    # import-from-derivation — cheap and cached, but an eval now needs a
    # build step (the k host on darwin; nebula's Mac-side cross-eval already
    # needs one for devenv's cachix input).
    devenv-src = {
      url = "github:cachix/devenv/2a399e9ea5e981f225d75b25c8fa8d76f730131d";
      flake = false;
    };
    # Evaluates a patched flake source (the devenv overlay above).
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
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
