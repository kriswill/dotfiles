{
  flake.modules.darwin.apple-container =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.kriswill.apple-container;
      user = config.system.primaryUser;
      container = lib.getExe pkgs.apple-container; # $out/bin/container (the wrapper)
    in
    {
      options.kriswill.apple-container.enable = lib.mkEnableOption "Apple's native macOS container CLI";

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ pkgs.apple-container ];

        # Guard 1 — refuse to install over a foreign (manual .pkg / Homebrew) install.
        # Runs as root under `set -e`; `if` conditions are exempt, and `exit 1` aborts the
        # switch before the new generation becomes current. Nix never writes /usr/local or
        # registers pkgutil receipts, so any of these signals means a non-Nix install.
        system.activationScripts.preActivation.text = lib.mkAfter ''
          if /usr/sbin/pkgutil --pkg-info com.apple.container-installer >/dev/null 2>&1 \
            || [ -e /usr/local/bin/container ] \
            || [ -x /opt/homebrew/bin/container ]; then
            echo >&2 "error: apple-container: a non-Nix 'container' is already installed."
            echo >&2 "  Detected a manual install (pkgutil receipt com.apple.container-installer"
            echo >&2 "  and/or /usr/local/bin/container). Remove it, then re-run the rebuild:"
            echo >&2 "    sudo /usr/local/bin/uninstall-container.sh   # if the installer left one"
            echo >&2 "    sudo pkgutil --forget com.apple.container-installer"
            exit 1
          fi
        '';

        # Guard 2 — on a store-path change, bring the old runtime down (best-effort) in
        # ${user}'s launchd domain (the CLI registers its services in user/<uid>), then
        # prompt to start the new build. Every command is `|| true`-guarded so a failed stop
        # never aborts the switch. We deliberately do NOT auto-start (start needs the user's
        # live launchd session and prompts to download a kernel on first run).
        system.activationScripts.postActivation.text = lib.mkAfter ''
          acUid="$(/usr/bin/id -u ${user} 2>/dev/null || true)"
          acPlist="/Users/${user}/Library/Application Support/com.apple.container/apiserver/apiserver.plist"
          acNew="${pkgs.apple-container}"
          if [ -n "$acUid" ] && [ -f "$acPlist" ]; then
            acCur="$(/usr/bin/plutil -extract EnvironmentVariables.CONTAINER_INSTALL_ROOT raw "$acPlist" 2>/dev/null || true)"
            if [ -n "$acCur" ] && [ "$acCur" != "$acNew" ]; then
              echo "apple-container: runtime is on an old build:"
              echo "  old: $acCur"
              echo "  new: $acNew"
              echo "apple-container: stopping old runtime (best-effort, in ${user}'s launchd domain)…"
              /bin/launchctl asuser "$acUid" /usr/bin/sudo -u ${user} ${container} system stop || true
              echo "apple-container: run 'container system start' to bring up the new build"
            fi
          fi
        '';
      };
    };
}
