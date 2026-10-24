# Daily reminder to remake our herdr fork: fires when upstream
# (herdrdev/herdr) publishes a stable release newer than the base of our
# `vX.Y.Z-custom` tag — the signal to rebase the `custom` branch onto the new
# release, tag it `vA.B.C-custom`, and repoint the herdr input in flake.nix.
# Our side is pkgs.herdr.version (the fork package's own X.Y.Z, so it tracks
# the input with no number to keep in sync); upstream's is one GitHub API call
# to releases/latest, which skips the `preview-*` prereleases. nixpkgs' herdr
# is irrelevant. Pops a dismissable critical notification; clicking the action
# opens the new release's page. The check itself: ./herdr-update-check.sh.
{
  configurations.nixos.nebula.module =
    { lib, pkgs, ... }:
    let
      check = pkgs.writeShellApplication {
        name = "herdr-update-check";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.jq
          pkgs.libnotify
          pkgs.xdg-utils
        ];
        text = builtins.readFile ./herdr-update-check.sh;
      };
    in
    {
      systemd.user.services.herdr-update-check = {
        description = "Notify when upstream herdr releases past our v${pkgs.herdr.version}-custom fork (rebase the patches)";
        # notify-send -A blocks until the notification is clicked or
        # dismissed (up to the script's 12h timeout). Type=exec, not oneshot: a
        # oneshot stays "activating" that whole time, so anything that starts
        # it synchronously waits on the click — switch-to-configuration
        # restarts changed active/activating user units and blocks on the job
        # BEFORE starting the system units it stopped, so an unanswered
        # notification hung `nrs` at "Activating configuration" with
        # NetworkManager & co. down. restartIfChanged = false keeps a switch
        # from tearing down (and re-popping) a pending notification.
        restartIfChanged = false;
        environment.HERDR_FORK_VERSION = pkgs.herdr.version;
        serviceConfig = {
          Type = "exec";
          ExecStart = lib.getExe check;
        };
      };

      systemd.user.timers.herdr-update-check = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          # Fire on next login if the machine was off/asleep at the scheduled time.
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    };
}
