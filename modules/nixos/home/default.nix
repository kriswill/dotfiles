{ config, lib, options, pkgs, ... }:
let
  inherit (lib) types mkAliasDefinitions;
  inherit (lib.internal) mkOpt;
in
{

  options.k.home = with types; {
    configFile =
      mkOpt attrs { }
        "A set of files to be managed by home-manager's <option>xdg.configFile</option>.";
    extraOptions = mkOpt attrs { } "Options to pass directly to home-manager.";
    file =
      mkOpt attrs { }
        "A set of files to be managed by home-manager's <option>home.file</option>.";
  };

  config = {
    environment.systemPackages = [
      pkgs.home-manager
    ];

    k.home.extraOptions = {
      home.file = mkAliasDefinitions options.k.home.file;
      home.stateVersion = config.system.stateVersion;
      xdg.configFile = mkAliasDefinitions options.k.home.configFile;
      xdg.enable = true;
    };

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;

      users.${config.k.user.name} =
        mkAliasDefinitions options.k.home.extraOptions;
    };
  };
}
