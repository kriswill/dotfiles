{
  flake.modules.darwin.fastfetch =
    # Nixos twin: modules/nixos/fastfetch.nix. Hosts pick their logo via
    # programs.fastfetch.logo; the wrapper's CLI flags beat the stowed
    # config.jsonc's `source` (docs/fastfetch.md).
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.programs.fastfetch = {
        logo = lib.mkOption {
          type = lib.types.str;
          default = "hexley-nix.png";
          description = "Logo image filename under ~/.config/fastfetch/ (stow package `fastfetch`).";
        };
        logoPaddingTop = lib.mkOption {
          type = lib.types.ints.unsigned;
          # Hexley is wide: width-fit leaves ~13 rows beside ~19 rows of
          # output, so drop it toward vertical center.
          default = 3;
          description = "Blank rows above the logo.";
        };
      };

      config.environment.systemPackages = [
        (import ../../lib/fastfetch-logo-wrapper.nix {
          inherit pkgs;
          inherit (config.programs.fastfetch) logo;
          paddingTop = config.programs.fastfetch.logoPaddingTop;
        })
      ];
    };
}
