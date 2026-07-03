{
  flake.modules.darwin.dnsmasq =
    { lib, ... }:
    {
      services.dnsmasq = {
        enable = lib.mkDefault true;
        bind = lib.mkDefault "127.0.0.1";
        # addresses is types.attrs (values consumed raw, no per-key merging),
        # so the default applies to the set as a whole.
        addresses = lib.mkDefault {
          localhost = "127.0.0.1";
          p4c = "127.0.0.1";
        };
      };
    };
}
