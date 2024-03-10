{ config, lib, ...}:
let
  inherit (lib.internal) enabled;
in
{
  k = {
    user = {
      enable = true;
      inherit (config.snowfallorg.user) name;
    };

    cli-apps = {
      home-manager = enabled;
    };

    # system = {
    #   xdg = enabled;
    # };

    suites = {
      common = enabled;
      development = enabled;
    };

    tools = {
      git = enabled;
      # ssh = enabled;
    };
  };

  home.stateVersion = "23.11";
}
