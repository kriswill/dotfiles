{ inputs, ... }: {

  imports = with inputs; [
    devshell.flakeModule
    pre-commit-hooks.flakeModule
    treefmt-nix.flakeModule
  ];

  perSystem = { config, pkgs, lib, system, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [
        inputs.nur.overlay
        # attach nixpkgs-unstable to pkgs.unstable
        (final: prev: {
          unstable = import inputs.nixpkgs-unstable {
            inherit (final) system;
            config.allowUnfree = true;
          };
          trunk = import inputs.nixpkgs-trunk {
            inherit (final) system;
            config.allowUnfree = true;
          };
          wallpapers = import ../packages/shared/wallpapers.nix;
          xdg-desktop-portal-gtk = (prev.xdg-desktop-portal-gtk.overrideAttrs {
            postInstall = ''
              sed -i 's/UseIn=gnome/UseIn=gnome;Hyprland;none+i3/' $out/share/xdg-desktop-portal/portals/gtk.portal
            '';
          }).override { buildPortalsInGnome = false; };
        })
      ];
      config = { allowUnfree = true; };
    };

    packages = {
      tilingshell = import ../packages/tilingshell {
        inherit (pkgs) stdenvNoCC lib fetchzip;
      };

      distro-grub-themes-nixos = import ../packages/distro-grub-themes {
        inherit (pkgs) stdenvNoCC fetchurl;
      };
    };

    devshells.default = let
      inherit (lib) getExe;
      nix = ''
        $([ "$\{USE_NOM:-0}" = '1' ] && echo ${
          getExe pkgs.unstable.nix-output-monitor
        } || echo nix)'';
      nixfmt = pkgs.unstable.nixfmt-rfc-style;
    in {
      packages = with pkgs.unstable; [ git ripgrep fd fzf nixfmt ];

      commands = [
        {
          name = "checks";
          help = "Run all flake checks";
          command = ''
            echo "=> Running all flake checks..."
            ${nix} flake check "$@"
          '';
        }
        {
          name = "format";
          help = "Format all the files";
          command = "nix fmt";
        }
      ];
    };

    formatter = pkgs.unstable.nixfmt;

    treefmt.config = {
      projectRootFile = "flake.nix";

      programs = {
        nixfmt.enable = true;
        statix.enable = true;
      };
    };

    pre-commit = {
      check.enable = true;
      settings = {
        excludes = [ "flake.lock" ".direnv/*" ];
        hooks = {
          stylua.enable = true;
          rfc101 = {
            enable = true;
            name = "RFC-101 formatting";
            entry = "${pkgs.lib.getExe pkgs.unstable.nixfmt-rfc-style}";
            files = "\\.nix$";
          };
        };
      };
    };
  };
}
