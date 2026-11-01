# nix-darwin module, exported as `darwinModules.herdr` (and `default`): the
# shared options and config (./common.nix), plus what only nix-darwin does
# here — config files as links made by the activation script, and the update
# check as a launchd user agent. No linger: on macOS hc starts its core as a
# plain detached process.
#
# programs.herdr-app is Linux-only for now. Upstream's macOS app is a
# Developer ID-signed Herdr.app: the telemetry wrapper can't reach a bundle
# launched from Finder, and its self-updater would find the bundle and fail
# against the read-only store every 30 minutes (README: darwin).
self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  core = config.programs.herdr-core;
  app = config.programs.herdr-app;
  check = config.services.herdr-update-check;
  toml = pkgs.formats.toml { };

  # nix-darwin leaves users.users.<name>.home null unless a host sets it.
  homeOf = user: config.users.users.${user}.home or null;
  home = user: if homeOf user != null then homeOf user else "/Users/${user}";
in
{
  imports = [ (import ./common.nix self) ];

  options.services.herdr-update-check.startCalendarInterval = lib.mkOption {
    type = lib.types.listOf (lib.types.attrsOf lib.types.int);
    default = [
      {
        Hour = 10;
        Minute = 0;
      }
    ];
    description = ''
      When the check runs (launchd `StartCalendarInterval`: entries of
      `Minute`, `Hour`, `Day`, `Weekday`, `Month`). launchd runs a time missed
      while the Mac slept once it wakes.
    '';
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !app.enable;
          message = ''
            programs.herdr-app is Linux-only for now: upstream's signed
            Herdr.app can't take the telemetry wrapper, and its self-updater
            would fail against the read-only Nix store every 30 minutes. See
            flakes/herdr/README.md, "darwin".
          '';
        }
      ];
    }

    (lib.mkIf (core.enable && core.settings != null) {
      # Order 1600: after a dotfiles stow (1500), as in this repo's own
      # modules. Run as the user so the directory isn't root-owned; `ln -sfn`
      # replaces any stale link so the store path tracks rebuilds.
      system.activationScripts.postActivation.text =
        let
          file = toml.generate "herdr-core-config.toml" core.settings;
        in
        lib.mkOrder 1600 (
          lib.concatMapStrings (user: ''
            /usr/bin/sudo -u ${lib.escapeShellArg user} --set-home /bin/sh -c \
              ${lib.escapeShellArg "mkdir -p '${home user}/.config/herdr-core' && ln -sfn '${file}' '${home user}/.config/herdr-core/config.toml'"}
          '') core.users
        );
    })

    (lib.mkIf check.enable {
      launchd.user.agents.herdr-update-check.serviceConfig = {
        ProgramArguments = [
          (lib.getExe check.package)
          "--notify"
        ];
        EnvironmentVariables = check.environment;
        StartCalendarInterval = check.startCalendarInterval;
        ProcessType = "Background";
      };
    })
  ];
}
