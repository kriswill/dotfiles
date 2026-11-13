# mini keeps a logged-in desktop for Hermes, but opens optional GUI apps
# on demand. See knowledge/modules/headless-login.md for verification
# and rollback; macOS session restoration and login items are separate.
{
  configurations.darwin.mini.module =
    { config, lib, ... }:
    {
      system.defaults.CustomUserPreferences."com.apple.loginwindow" = {
        # Present in mini's macOS 27.2.1 loginwindow. Its persistent-app
        # launch/save paths check this flag; the old
        # LoginwindowLaunchesRelaunchApps key is absent from that binary.
        TALBlockSavingAndLaunch = true;
        TALLogoutSavesState = false;
      };

      system.activationScripts.postActivation.text = lib.mkAfter ''
        # Disable only 1Password's login launcher. The main app and its
        # browser helper remain available when explicitly needed. launchd
        # persists this override across boots; no running app is stopped.
        mini_login_uid=$(/usr/bin/id -u ${lib.escapeShellArg config.system.primaryUser})
        if /bin/launchctl print "gui/$mini_login_uid" >/dev/null 2>&1; then
          echo "disabling 1Password's login launcher on mini..." >&2
          /bin/launchctl disable "gui/$mini_login_uid/com.1password.1password-launcher"
        else
          echo "mini: no GUI login domain; rerun nrs after login to disable 1Password's launcher" >&2
        fi
      '';
    };
}
