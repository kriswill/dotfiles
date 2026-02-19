{ lib, config, ... }:
{
  options.kriswill.dnsmasq.enable = lib.mkEnableOption "dnsmasq local DNS service";
  config = lib.mkIf config.kriswill.dnsmasq.enable {
    services.dnsmasq = {
      enable = true;
      bind = "127.0.0.1";
      addresses = {
        localhost = "127.0.0.1";
        p4c = "127.0.0.1";
      };
    };
  };
}
