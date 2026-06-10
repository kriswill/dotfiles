{
  flake.modules.homeManager.apple-container =
    {
      lib,
      config,
      pkgs,
      ...
    }:

    {
      options.kriswill.apple-container.enable = lib.mkEnableOption "Apple's native macOS container CLI";

      config = lib.mkIf config.kriswill.apple-container.enable {
        # Just the CLI on PATH. Apple's own `container system start` manages the
        # apiserver launchd service and kernel — we deliberately don't wrap that.
        home.packages = [ pkgs.apple-container ];
      };
    };
}
