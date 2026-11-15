# mini keeps a logged-in desktop for Hermes and normal 1Password login
# launch. See knowledge/modules/headless-login.md for verification
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
        # Clear the disable override installed by generation 28. Let the
        # app's normal login registration run; do not open/unlock it here.
        mini_login_uid=$(/usr/bin/id -u ${lib.escapeShellArg config.system.primaryUser})
        if /bin/launchctl print "gui/$mini_login_uid" >/dev/null 2>&1; then
          echo "enabling 1Password's normal login launcher on mini..." >&2
          /bin/launchctl enable "gui/$mini_login_uid/com.1password.1password-launcher"
        else
          echo "mini: no GUI login domain; rerun nrs after login to clear the old 1Password launcher override" >&2
        fi
      '';
    };
}
