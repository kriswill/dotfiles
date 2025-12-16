{ lib, config, ... }:
{
  options.kriswill.alias-en0.enable = lib.mkEnableOption "en0 local IP address alias - used for dev";
  config = lib.mkIf config.kriswill.alias-en0.enable {
    launchd.daemons.alias-en0 = {
      serviceConfig = {
        Label = "com.local.alias.en0";
        ProgramArguments = [
          "/sbin/ifconfig"
          "en0"
          "alias"
          "10.11.12.1/24"
        ];
        RunAtLoad = true;
      };
    };
  };
}
