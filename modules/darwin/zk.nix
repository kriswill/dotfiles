# Kris' zk (system-level port of the old home-manager module).
#
# programs.zk in home-manager only installed the binary (no generated config),
# so the darwin port is just the package behind the enable toggle. zk reads its
# own ~/.config/zk/config.toml at runtime if present (not managed here).
{
  flake.modules.darwin.zk =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    {
      options.kriswill.zk.enable = lib.mkEnableOption "Kris' zk";
      config = lib.mkIf config.kriswill.zk.enable {
        environment.systemPackages = [ pkgs.zk ];
      };
    };
}
