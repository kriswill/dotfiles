# Alias a local dev IP onto en0 (work host only).
{
  configurations.darwin.SOC-Kris-Williams.module = {
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
