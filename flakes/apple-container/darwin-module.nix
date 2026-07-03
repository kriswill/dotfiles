# nix-darwin module for apple-container, exported as `darwinModules.apple-container`.
# Parameterized over this flake's `self` so `package` defaults to the flake's own
# build for the host system — consumers need no overlay or callPackage wiring.
self:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.services.apple-container;
  user = config.system.primaryUser;
  container = lib.getExe cfg.package; # $out/bin/container (the wrapper)
in
{
  options.services.apple-container = {
    enable = lib.mkEnableOption "Apple's native macOS container CLI";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.apple-container;
      defaultText = lib.literalExpression "apple-container.packages.\${system}.apple-container";
      description = "The apple-container package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    system = {
      # Both guards interpolate ${user}; registering here turns a null
      # system.primaryUser into nix-darwin's friendly migration assertion instead
      # of a raw "cannot coerce null to a string" for external consumers.
      requiresPrimaryUser = [ "services.apple-container.enable" ];

      # Guard 1 — refuse to activate over a foreign (manual .pkg / Homebrew) install.
      # Lives in system.checks so `darwin-rebuild check` exercises it without switching.
      # Caveat: `darwin-rebuild switch` sets the system profile BEFORE running
      # activation, so a failed check blocks activation but the profile already points
      # at the new generation — boot-time activation would bring it live, hence the
      # note in the error. A ghost pkgutil receipt (binaries already removed by hand)
      # only warns; an actual foreign binary fails the check.
      checks.text = lib.mkAfter ''
        acForeign=
        for acBin in /usr/local/bin/container /opt/homebrew/bin/container; do
          if [ -x "$acBin" ]; then
            acForeign="''${acForeign:+$acForeign, }$acBin"
          fi
        done
        if [ -n "$acForeign" ]; then
          echo >&2 "error: apple-container: a non-Nix 'container' binary is installed: $acForeign"
          echo >&2 "  Remove it, then re-run the rebuild:"
          echo >&2 "    sudo /usr/local/bin/uninstall-container.sh   # manual .pkg install"
          echo >&2 "    sudo pkgutil --forget com.apple.container-installer"
          echo >&2 "    brew uninstall container                     # Homebrew install"
          echo >&2 "  If this is an unrelated tool that happens to be named 'container',"
          echo >&2 "  rename it or disable services.apple-container."
          echo >&2 "  Note: after a failed 'switch' the system profile already points at the"
          echo >&2 "  new generation — resolve this (or 'darwin-rebuild rollback') before rebooting."
          exit 1
        elif /usr/sbin/pkgutil --pkg-info com.apple.container-installer >/dev/null 2>&1; then
          echo >&2 "warning: apple-container: stale pkgutil receipt com.apple.container-installer"
          echo >&2 "  (no 'container' binary found alongside it). Tidy up with:"
          echo >&2 "    sudo pkgutil --forget com.apple.container-installer"
        fi
      '';

      # Guard 2 — on a store-path change, bring the old runtime down (best-effort) in
      # ${user}'s launchd domain (the CLI registers its services in user/<uid>). We
      # deliberately do NOT auto-start: `container system start` needs the user's live
      # launchd session and interactively prompts to download a kernel on first run.
      # Abnormal paths warn instead of silently skipping; only "runtime never started"
      # and "already on the new build" stay quiet.
      activationScripts.postActivation.text = lib.mkAfter ''
        acHome="$(/usr/bin/dscl . -read /Users/${user} NFSHomeDirectory 2>/dev/null | /usr/bin/sed -n 's/^NFSHomeDirectory: //p' || true)"
        acPlist="$acHome/Library/Application Support/com.apple.container/apiserver/apiserver.plist"
        acNew="${cfg.package}"
        if [ -z "$acHome" ]; then
          echo >&2 "warning: apple-container: could not resolve ${user}'s home directory;"
          echo >&2 "  skipping the runtime store-path check"
        elif [ -f "$acPlist" ]; then
          acCur="$(/usr/bin/plutil -extract EnvironmentVariables.CONTAINER_INSTALL_ROOT raw "$acPlist" 2>/dev/null || true)"
          if [ -z "$acCur" ]; then
            echo >&2 "warning: apple-container: could not read CONTAINER_INSTALL_ROOT from"
            echo >&2 "  $acPlist (upstream layout change?) — cannot verify the running runtime"
            echo >&2 "  matches the installed build"
          elif [ "$acCur" != "$acNew" ]; then
            echo "apple-container: runtime is on an old build:"
            echo "  old: $acCur"
            echo "  new: $acNew"
            acUid="$(/usr/bin/id -u ${user} 2>/dev/null || true)"
            if [ -n "$acUid" ] \
              && /bin/launchctl asuser "$acUid" /usr/bin/sudo -u ${user} ${container} system stop; then
              echo "apple-container: old runtime stopped — run 'container system start' to bring up the new build"
            else
              echo >&2 "warning: apple-container: could not stop the old runtime (no active login"
              echo >&2 "  session for ${user}?) — run 'container system stop && container system start'"
              echo >&2 "  as ${user} to move the runtime onto the new build"
            fi
          fi
        fi
      '';
    };
  };
}
