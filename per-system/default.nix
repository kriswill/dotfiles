{ inputs, ... }:
{

  imports = [
    inputs.devshell.flakeModule
    inputs.pre-commit-hooks.flakeModule
    inputs.treefmt-nix.flakeModule
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
        #overlays = with inputs; [
        # agenix-rekey.overlays.default
        # fenix.overlays.default
        # nuenv.overlays.default
        # self.overlays.nixpkgs-unstable
        #];
        config = {
          allowUnfree = true;
        };
      };

      devshells.default = {
        packages = with pkgs; [
          git
          ripgrep
          fd
          fzf
        ];

        commands =
          let
            nix = ''$([ "$\{USE_NOM:-0}" = '1' ] && echo ${lib.getExe pkgs.nix-output-monitor} || echo nix)'';
          in
          [
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

      formatter = pkgs.nixfmt-rfc-style;

      treefmt.config = {
        projectRootFile = "flake.nix";

        programs = {
          nixfmt = {
            enable = true;
            package = pkgs.nixfmt-rfc-style;
          };
          statix.enable = true;
        };
      };

      pre-commit = {
        check.enable = true;
        settings = {
          excludes = [ "flake.lock" ];
          hooks = {
            stylua.enable = true;
            nixfmt = {
              enable = true;
              package = pkgs.nixfmt-rfc-style;
            };
          };
        };
      };
    };
}
