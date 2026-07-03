{
  flake.modules.darwin.dnsmasq = {
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
