{
  config,
  lib,
  ...
}:
let
  cfg = config.kriswill.zk;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
in
{
  options.kriswill.zk = {
    enable = mkEnableOption "zk";
  };
  config = mkIf cfg.enable {
    programs.zk.enable = true;
  };
}
