# NixOS module, exported as `nixosModules.herdr` (and `default`): the shared
# options and config (./common.nix), plus what only NixOS does here — linger
# for hc's users, config files as systemd-tmpfiles links, the GPU stack for
# the app, and the update check as a systemd user timer.
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

  # tmpfiles rules linking ~/.config/<dir>/<name> to `file` for every core
  # user: `L+` replaces whatever is there, at boot and on every switch.
  links =
    dir: name: file:
    lib.concatMap (
      user:
      let
        inherit (config.users.users.${user}) home group;
      in
      [
        "d ${home}/.config/${dir} 0755 ${user} ${group} - -"
        "L+ ${home}/.config/${dir}/${name} - - - - ${file}"
      ]
    ) core.users;
in
{
  imports = [ (import ./common.nix self) ];

  options.programs.herdr-core.linger = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Declare `users.users.<name>.linger = true` for each of `users`. The core
      runs as a transient unit of the user's systemd manager; without linger,
      that manager, the core and every terminal in it stop when the user's
      last login ends. hc turns linger on by itself the first time it starts a
      core (`loginctl enable-linger`, which polkit allows a user for
      themselves); declaring it makes that visible here. Lingering starts the
      user's manager at boot, so units wanted by their `default.target`
      (timers, paths) run before they log in.

      `false` declares nothing: it does not keep linger off, since hc would
      turn it back on.
    '';
  };

  options.services.herdr-update-check.calendar = lib.mkOption {
    type = lib.types.str;
    default = "daily";
    example = "*-*-* 09:00";
    description = ''
      When the check runs (systemd.time OnCalendar syntax), with up to an
      hour's random delay; a missed run catches up at the next start.
    '';
  };

  config = lib.mkMerge [
    (lib.mkIf core.enable {
      users.users = lib.mkIf core.linger (
        lib.genAttrs core.users (_: {
          linger = true;
        })
      );
      systemd.tmpfiles.rules = lib.optionals (core.settings != null) (
        links "herdr-core" "config.toml" (toml.generate "herdr-core-config.toml" core.settings)
      );
    })

    (lib.mkIf app.enable {
      # The window draws with Vulkan (or GL); either needs the system driver.
      hardware.graphics.enable = lib.mkDefault true;
      systemd.tmpfiles.rules = lib.optionals (app.keys != null) (
        links "herdr-app" "keys.json" (json.generate "herdr-app-keys.json" app.keys)
      );
    })

    (lib.mkIf check.enable {
      systemd.user.services.herdr-update-check = {
        description = "Notify when a herdr is behind upstream, or running an older build than installed";
        # Only for hc's users, when there are any (`|` ORs the conditions).
        unitConfig.ConditionUser = map (user: "|${user}") core.users;
        # notify-send -A blocks until the notification is answered (12h at
        # most). Type=exec, not oneshot: a oneshot stays "activating" all that
        # time, and switch-to-configuration waits on activating user units it
        # restarts, so a switch would hang on an unanswered notification.
        # restartIfChanged = false keeps a switch from tearing a pending one
        # down (and re-raising it).
        restartIfChanged = false;
        serviceConfig = {
          Type = "exec";
          ExecStart = "${lib.getExe check.finalPackage} --notify";
        };
      };
      systemd.user.timers.herdr-update-check = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = check.calendar;
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    })
  ];
}
