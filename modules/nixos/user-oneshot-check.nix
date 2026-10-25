# Evaluation warning for the user units that hung `nrs` on 2026-10-24: a
# oneshot that nothing starts at login (a path unit, a timer or a person
# starts it), that does not stay active, and that a switch would still
# restart. switch-to-configuration-ng restarts changed user units, `activating`
# ones included, and waits on those jobs with no timeout BEFORE it restarts
# the system services it stopped, so a capture mid-sleep holds the network
# down until it exits. The warning prints while the system evaluates, before
# anything changes. Rule and history:
# knowledge/decisions/user-oneshots-skip-switch-restart.md.
{
  flake.modules.nixos.user-oneshot-check =
    { config, lib, ... }:
    let
      # serviceConfig values are free-form: systemd booleans may be strings.
      isTrue =
        v:
        lib.elem v [
          true
          "true"
          "yes"
          "on"
          "1"
        ];
      hazardous =
        svc:
        svc.enable
        && (svc.serviceConfig.Type or "simple") == "oneshot"
        && !isTrue (svc.serviceConfig.RemainAfterExit or false)
        && svc.restartIfChanged
        && svc.wantedBy == [ ];
    in
    {
      warnings = lib.mapAttrsToList (
        name: _:
        "systemd.user.services.${name}: a trigger-started oneshot that a switch restarts, so a switch can block on it while system services are down; set restartIfChanged = false or make it Type=exec (knowledge/decisions/user-oneshots-skip-switch-restart.md)"
      ) (lib.filterAttrs (_: hazardous) config.systemd.user.services);
    };
}
