# Boot activation restores /etc and keyboard settings; full rebuild probes
# belong to nrs, where applications, users, Homebrew, and Nix can change.
{
  flake.modules.darwin.boot-activation =
    { lib, ... }:
    {
      # Wrap system.checks only: upstream appends the /etc hash/conflict
      # checks separately to system.activationScripts.checks, so they still
      # protect boot-time /etc repair. Do not override that combined script.
      system.checks.text = lib.mkMerge [
        (lib.mkBefore ''
          if [[ "''${NIX_DARWIN_BOOT_ACTIVATION:-0}" != 1 ]]; then
        '')
        # applications.nix contributes its permission probe at mkAfter (1500).
        (lib.mkOrder 2000 ''
          fi
        '')
      ];

      launchd.daemons.activate-system = {
        # This flag is local to the boot script. Normal activation clears its
        # environment, and nrs --test also runs the full checks under env -i.
        script = lib.mkBefore ''
          NIX_DARWIN_BOOT_ACTIVATION=1
          boot_started=$SECONDS
          printf 'nix-darwin boot activation started %s\n' "$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"
          trap 'boot_status=$?; printf "nix-darwin boot activation finished: status=%s elapsed=%ss\n" "$boot_status" "$((SECONDS - boot_started))"' EXIT
        '';
        serviceConfig = {
          StandardOutPath = "/var/log/nix-darwin-boot.log";
          StandardErrorPath = "/var/log/nix-darwin-boot.log";
        };
      };
    };
}
