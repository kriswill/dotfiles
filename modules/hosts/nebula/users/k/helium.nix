# Helium user tooling for `k`.
#
# helium-config — snapshot/restore Helium's user settings (Bookmarks + .bak,
# Preferences, Local State, Cookies, Login Data) into the dotfiles repo
# (config/helium/...) WITHOUT symlinking the live profile. Helium (Chromium)
# rewrites those files via atomic rename, which breaks a stow symlink on the
# first save; and `home/` is auto-restowed every rebuild, so a home/helium
# package would symlink the repo copy over the live profile and clobber the
# running config. So we sync explicitly: `helium-config capture` after settings
# edits, `restore` on a fresh machine (quit Helium first). Allowlist-only, and
# every snapshot is age-encrypted — Cookies/Login Data hold live credentials, so
# the repo carries only ciphertext. Same pattern as noctalia-config. The
# system-level Helium config (browser
# enable + managed policies) lives in modules/nixos/helium/.
# See pkgs/helium-config.nix.
{
  configurations.nixos.nebula.module =
    { lib, pkgs, ... }:
    {
      users.users.k.packages = [ pkgs.helium-config ];

      # Auto-capture on the allowlisted files (see pkgs/helium-config.sh).
      # Guarded: while Helium runs, Cookies/Login Data (live SQLite) could
      # snapshot torn, so the service skips — Chromium rewrites Preferences/
      # Local State on clean exit, and THOSE events fire the real capture once
      # the browser is gone. Debounce is the sleep (path triggers are
      # suppressed while the service runs); no TriggerLimit* — exceeding it
      # would fail the path unit and stop the watching.
      systemd.user.paths.helium-config-capture = {
        wantedBy = [ "paths.target" ];
        pathConfig.PathChanged = [
          "%h/.config/net.imput.helium/Default/Bookmarks"
          "%h/.config/net.imput.helium/Default/Preferences"
          "%h/.config/net.imput.helium/Local State"
          "%h/.config/net.imput.helium/Default/Cookies"
          "%h/.config/net.imput.helium/Default/Login Data"
        ];
      };
      systemd.user.services.helium-config-capture = {
        path = [ pkgs.procps ];
        serviceConfig.Type = "oneshot";
        serviceConfig.ExecStart = pkgs.writeShellScript "helium-config-capture" ''
          sleep 30
          if pgrep -x helium >/dev/null 2>&1; then
            echo "helium running — skipping capture (exit-time writes will re-trigger)"
            exit 0
          fi
          exec ${lib.getExe pkgs.helium-config} capture
        '';
      };
    };
}
