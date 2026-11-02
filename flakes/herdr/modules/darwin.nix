# nix-darwin module, exported as `darwinModules.herdr` (and `default`): the
# shared options and config (./common.nix), plus what only nix-darwin does
# here — config files as links made by the activation script, the app's
# choices written into settings.json, and the update check as a launchd user
# agent. No linger: on macOS hc starts its core as a plain detached process.
#
# programs.herdr-app installs upstream's signed Herdr.app (../pkgs/herdr-app.nix),
# which nix-darwin copies into "/Applications/Nix Apps". Finder launches the
# bundle itself, so the Linux wrapper's environment (HERDR_TELEMETRY,
# HERDR_CORE_DIRS, the settings merge before each launch) can't reach it.
# Herdr reads the same choices from settings.json: `telemetry` and `core`
# (upstream src/settings.rs `Person`, src/core_bin.rs `find`), so at
# activation this module merges them, with programs.herdr-app.settings, into
# each core user's ~/.config/herdr-app/settings.json (declared keys win; the
# app's own edits to other keys stay; a stow symlink is written through).
#
# The core pin is `/etc/herdr-core/hc`, a link to programs.herdr-core.package,
# rather than the store path: Herdr leads every terminal's PATH with the folder
# it found hc in, and /etc/herdr-core holds only hc, so it shadows nothing;
# and a stable path keeps a store hash out of settings.json, which is a repo
# file when stow owns it. hc canonicalizes its own path before deciding who
# manages it, so it still counts as nix-installed (no `hc update` offers).
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
  json = pkgs.formats.json { };
  toml = pkgs.formats.toml { };

  # nix-darwin leaves users.users.<name>.home null unless a host sets it.
  homeOf = user: config.users.users.${user}.home or null;
  home = user: if homeOf user != null then homeOf user else "/Users/${user}";

  # Run a shell snippet as each core user (so nothing under their home ends up
  # root-owned), from the activation script.
  forCoreUsers =
    snippet:
    lib.concatMapStrings (user: ''
      /usr/bin/sudo -u ${lib.escapeShellArg user} --set-home /bin/sh -c ${lib.escapeShellArg (snippet user)}
    '') core.users;
  # `ln -sfn` replaces any stale link so the store path tracks rebuilds.
  link =
    dir: name: file: user:
    "mkdir -p '${home user}/.config/${dir}' && ln -sfn '${file}' '${home user}/.config/${dir}/${name}'";

  corePin = "/etc/herdr-core/hc";
  # What the Linux wrapper would set in the environment, as settings.json keys.
  declared =
    lib.optionalAttrs (!app.telemetry) { telemetry = false; }
    // lib.optionalAttrs core.enable { core = corePin; }
    // app.settings;
  merge = pkgs.callPackage ../pkgs/herdr-app-merge-settings.nix { };
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
    # Order 1600: after a dotfiles stow (1500), as in this repo's own modules,
    # so a stowed settings.json is already in place to be written through.
    (lib.mkIf (core.enable && core.settings != null) {
      system.activationScripts.postActivation.text = lib.mkOrder 1600 (
        forCoreUsers (
          link "herdr-core" "config.toml" (toml.generate "herdr-core-config.toml" core.settings)
        )
      );
    })

    (lib.mkIf app.enable {
      environment.etc."herdr-core/hc" = lib.mkIf core.enable {
        source = "${lib.getBin core.package}/bin/hc";
      };
      warnings = lib.optional (declared != { } && core.users == [ ]) ''
        programs.herdr-app has settings to write (telemetry, the core pin,
        settings) but programs.herdr-core.users is empty, so no settings.json
        is written; Herdr runs with its own defaults (telemetry on).
      '';
      system.activationScripts.postActivation.text = lib.mkOrder 1600 (
        lib.optionalString (app.keys != null) (
          forCoreUsers (link "herdr-app" "keys.json" (json.generate "herdr-app-keys.json" app.keys))
        )
        + lib.optionalString (declared != { }) (
          forCoreUsers (_: "${lib.getExe merge} ${json.generate "herdr-app-settings.json" declared} || true")
        )
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
