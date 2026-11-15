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

      # Builtin timestamps avoid adding subprocess startup to the phases we
      # measure. Full nrs activation does not set the boot flag or log here.
      system.activationScripts = lib.genAttrs [ "checks" "etc" "keyboard" ] (phase: {
        text = lib.mkMerge [
          (lib.mkBefore ''
            if [[ "''${NIX_DARWIN_BOOT_ACTIVATION:-0}" == 1 ]]; then
              boot_phase=${phase}
              boot_log "$boot_phase begin"
            fi
          '')
          (lib.mkAfter ''
            if [[ "''${NIX_DARWIN_BOOT_ACTIVATION:-0}" == 1 ]]; then
              boot_log "${phase} end"
            fi
          '')
        ];
      });

      launchd.daemons.activate-system = {
        # This flag is local to the boot script. Normal activation clears its
        # environment, and nrs --test also runs the full checks under env -i.
        script = lib.mkBefore ''
          NIX_DARWIN_BOOT_ACTIVATION=1
          boot_started=$SECONDS
          boot_phase=runtime-profile
          boot_log() {
            printf '%s nix-darwin boot: %s elapsed=%ss\n' "$EPOCHREALTIME" "$1" "$((SECONDS - boot_started))"
          }
          boot_log "$boot_phase begin"
          printf 'nix-darwin boot activation started %s\n' "$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)"
          trap 'boot_status=$?; boot_log "finished status=$boot_status last-phase=$boot_phase"' EXIT
        '';
        serviceConfig = {
          StandardOutPath = "/var/log/nix-darwin-boot.log";
          StandardErrorPath = "/var/log/nix-darwin-boot.log";
        };
      };
    };
}
