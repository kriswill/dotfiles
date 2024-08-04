{ inputs, ... }: {
  imports = [ inputs.pre-commit-hooks.flakeModule ];

  perSystem.pre-commit.settings = {
    excludes = [ "flake.lock" ".direnv" ];

    hooks = {
      nil.enable = true;
      deadnix.enable = true;
      stylua.enable = true;
      treefmt.enable = true;
      statix = {
        enable = true;
        settings = {
          ignore = [ "./direnv/" ];
          format = "stderr";
        };
      };
    };
  };
}
