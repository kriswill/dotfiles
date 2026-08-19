{
  flake.modules.nixos.fastfetch =
    # Darwin twin: modules/darwin/fastfetch.nix. Hosts pick their logo via
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
          default = "Nebula.png";
          description = "Logo image filename under ~/.config/fastfetch/ (stow package `fastfetch`).";
        };
        logoPaddingTop = lib.mkOption {
          type = lib.types.ints.unsigned;
          default = 0;
          description = "Blank rows above the logo.";
        };
      };

      # snowglobe-factory already installs fastfetch via its own programs.fastfetch
      # options (enable/package/installGlobally) — our logo/logoPaddingTop
      # declarations merge into that set, and swapping the wrapped binary in
      # through its `package` option avoids shipping a colliding second copy.
      config.programs.fastfetch.package = import ../../lib/fastfetch-logo-wrapper.nix {
        inherit pkgs;
        inherit (config.programs.fastfetch) logo;
        paddingTop = config.programs.fastfetch.logoPaddingTop;
      };
    };
}
