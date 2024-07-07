{ self, inputs, ... }:
{

  imports = with inputs; [
    devshell.flakeModule
    pre-commit-hooks.flakeModule
    treefmt-nix.flakeModule
  ];

  perSystem =
    {
      config,
      pkgs,
      lib,
      system,
      ...
    }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          # attach nixpkgs-unstable to pkgs.unstable
          (final: prev: {
            unstable = import inputs.nixpkgs-unstable {
              x = builtins.trace "final = ${final}";
              inherit (final) system;
              config.allowUnfree = true;
            };
          })
        ];
        config = {
          allowUnfree = true;
        };
      };

      devshells.default =
        let
          nix = ''$([ "$\{USE_NOM:-0}" = '1' ] && echo ${lib.getExe pkgs.unstable.nix-output-monitor} || echo nix)'';
          nixfmt = pkgs.unstable.nixfmt-rfc-style;
        in
        {
          packages = with pkgs; [
            git
            ripgrep
            fd
            fzf
          ];

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
              command = ''${lib.getExe pkgs.unstable.nixfmt-rfc-style} "$@" **/*.nix'';
            }
          ];
        };

      formatter = pkgs.unstable.nixfmt-rfc-style;

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
          excludes = [
            "flake.lock"
            ".direnv/*"
          ];
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
