# Mini's boot credentials stay on sops-nix's protected RAM filesystem.
{
  configurations.darwin.mini.module =
    { config, lib, ... }:
    {
      # Both Mini files have age recipients only. Avoid constructing an
      # unused GPG keyring from the RSA host key on every secret install.
      # This does not change gpg-agent/pass or any other host's SOPS sources.
      sops.gnupg.sshKeyPaths = lib.mkForce [ ];

      launchd.daemons.sops-install-secrets.serviceConfig = {
        # Preserve upstream's install command and native mount wait. Add
        # timings without tracing commands, environment or secret contents.
        ProgramArguments = lib.mkForce [
          "/bin/sh"
          "-c"
          ''
            set -euo pipefail
            sops_started=$SECONDS
            sops_phase=store-wait
            sops_log() {
              printf '%s sops boot: %s elapsed=%ss\n' "$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$((SECONDS - sops_started))"
            }
            trap 'sops_status=$?; sops_log "finished status=$sops_status last-phase=$sops_phase"' EXIT
            sops_log "$sops_phase begin"
            /bin/wait4path ${config.sops.package}/bin/sops-install-secrets
            sops_phase=install
            sops_log "$sops_phase begin"
            ${config.launchd.daemons.sops-install-secrets.command}
          ''
        ];
        StandardOutPath = "/var/log/sops-boot.log";
        StandardErrorPath = "/var/log/sops-boot.log";
      };
    };
}
