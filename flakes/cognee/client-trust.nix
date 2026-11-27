{ isDarwin }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cognee.clientTrust;
  isLinux = !isDarwin;
  chromiumPolicy =
    pkgs.runCommand "cognee-ca-policy.json"
      {
        nativeBuildInputs = [
          pkgs.openssl
          pkgs.jq
        ];
        dnsNames = builtins.toJSON cfg.chromiumDnsNames;
      }
      ''
        openssl x509 -in ${lib.escapeShellArg cfg.certificateFile} -outform DER -out root.der
        openssl base64 -A -in root.der -out root.base64
        jq -n --rawfile certificate root.base64 --argjson names "$dnsNames" '{
          CACertificatesWithConstraints: [{
            certificate: $certificate,
            constraints: { permitted_dns_names: $names }
          }]
        }' > "$out"
      '';
in
{
  options.services.cognee.clientTrust = {
    enable = lib.mkEnableOption "trusting the Cognee HTTPS root CA on this client";
    certificateFile = lib.mkOption {
      type = lib.types.path;
      description = "Build-time PEM file containing the Cognee server's public root CA certificate.";
    };
  }
  // lib.optionalAttrs isLinux {
    chromiumDnsNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "cognee.home.arpa" ];
      description = "DNS names permitted by the optional managed Chromium CA policy.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      security.pki.certificateFiles = [ cfg.certificateFile ];
      environment.etc."ssl/certs/cognee-root.crt".source = cfg.certificateFile;
    })
    (lib.optionalAttrs isLinux {
      environment.etc."chromium/policies/managed/cognee-ca.json" = lib.mkIf (
        cfg.enable && cfg.chromiumDnsNames != [ ]
      ) { source = chromiumPolicy; };
    })
    (lib.optionalAttrs isDarwin {
      # Track the public certificate whose admin trust this module installed.
      # A rotation adds the new root before removing the old one.
      system.activationScripts.postActivation.text = lib.mkAfter ''
        (
          set -euo pipefail
          cognee_ca_state=/var/lib/cognee-client-trust
          cognee_previous_ca="$cognee_ca_state/root.crt"
          ${
            if cfg.enable then
              ''
                cognee_ca=${lib.escapeShellArg cfg.certificateFile}
                if [[ -f "$cognee_previous_ca" ]]; then
                  cognee_fingerprint=$(/usr/bin/openssl x509 -in "$cognee_ca" -noout -sha256 -fingerprint)
                  cognee_previous_fingerprint=$(/usr/bin/openssl x509 -in "$cognee_previous_ca" -noout -sha256 -fingerprint)
                  if [[ "$cognee_fingerprint" == "$cognee_previous_fingerprint" ]]; then
                    exit 0
                  fi
                fi
                /usr/bin/security add-trusted-cert -d -r trustRoot -p ssl \
                  -k /Library/Keychains/System.keychain "$cognee_ca"
                if [[ -f "$cognee_previous_ca" ]]; then
                  /usr/bin/security remove-trusted-cert -d "$cognee_previous_ca"
                fi
                /usr/bin/install -d -m 0700 -o root -g wheel "$cognee_ca_state"
                /usr/bin/install -m 0600 -o root -g wheel "$cognee_ca" "$cognee_previous_ca"
              ''
            else
              ''
                if [[ -f "$cognee_previous_ca" ]]; then
                  /usr/bin/security remove-trusted-cert -d "$cognee_previous_ca"
                  /bin/rm -f "$cognee_previous_ca"
                fi
              ''
          }
        )
      '';
    })
  ];
}
