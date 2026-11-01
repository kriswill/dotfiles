{
  description = "herdr — everything herdr in one flake: our herdr TUI fork, Herdr's desktop app and herdr-core (hc), helper tools, an update check, and NixOS + nix-darwin modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    # The herdr TUI from OUR staging fork's `v0.9.5-custom` tag (the `custom`
    # branch rebased onto upstream's v0.9.5 stable tag; the repo ships its own
    # flake; no binary cache, builds from source) plus our patch commits —
    # currently ANSI tab-bar command entries (ui.tab_bar_right `argv`/`ansi`
    # fields: run e.g. dotbar without a shell and render its SGR-colored
    # output inline; HERDR_TOKEN_* env from workspace metadata with reactive
    # re-runs) and opt-in nested-shell agent detection
    # (`experimental.follow_nested_shells`: agents under `devenv shell`/`script`
    # are detected, clear on return to the nested prompt, and survive
    # ctrl-z/fg), plus a test-only fix forcing ENV=/dev/null in
    # .cargo/config.toml so our ~/.kshrc (inherited via ENV, sourced by the
    # tests' interactive /bin/sh) can't time out the suite. Rebase `custom`
    # onto each new upstream tag, tag it `vX.Y.Z-custom`, and repoint the url
    # (herdr-update-check is the reminder); drop commits as they land
    # upstream. ≥ v0.8.2 is needed for the CSI 14t/16t pixel-size fix
    # (herdrdev/herdr#835) that nixpkgs' 0.7.5 lacks — required for image
    # rendering (fastfetch/yazi) inside herdr panes, together with
    # `experimental.kitty_graphics = true` in the stow config.toml; see
    # docs/fastfetch.md. rust-overlay is bumped past the tag's pin because
    # that pin predates upstream's stdenv.isLinux → hostPlatform fix and spams
    # deprecation warnings on every eval; drop the override with the input.
    herdr-cli = {
      url = "github:kriswill/herdr/v0.9.5-custom";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay = {
        url = "github:oxalica/rust-overlay";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # herdr-app is Linux-only for now (README: darwin); everything else
      # builds on the macs too.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        {
          pkgs,
          config,
          lib,
          inputs',
          ...
        }:
        {
          packages = {
            herdr-cli = import ./pkgs/herdr-cli.nix {
              herdr = inputs'.herdr-cli.packages.herdr;
              buildId = inputs.herdr-cli.shortRev or "dirty";
            };
            herdr-nav = pkgs.callPackage ./pkgs/herdr-nav.nix { herdr = config.packages.herdr-cli; };
            herdr-core = pkgs.callPackage ./pkgs/herdr-core.nix { };
            herdr-update-check = pkgs.callPackage ./pkgs/herdr-update-check.nix {
              cliVersion = config.packages.herdr-cli.version;
            };
            default = config.packages.herdr-cli;
          }
          // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            herdr-app-unwrapped = pkgs.callPackage ./pkgs/herdr-app.nix { };
            # Standalone: telemetry off, and this core on PATH (after any other
            # hc) so `nix run` finds one. The modules wrap their own.
            herdr-app = pkgs.callPackage ./pkgs/herdr-app-wrap.nix {
              package = config.packages.herdr-app-unwrapped;
              core = config.packages.herdr-core;
            };
          };
        };

      flake = {
        nixosModules = rec {
          herdr = import ./modules/nixos.nix self;
          default = herdr;
        };
        darwinModules = rec {
          herdr = import ./modules/darwin.nix self;
          default = herdr;
        };
      };
    };
}
