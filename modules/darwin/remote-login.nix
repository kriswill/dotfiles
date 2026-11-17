# Inbound SSH (macOS "Remote Login") kept on, with the named users allowed in.
#
# Two separate macOS switches gate an inbound login, and both can be flipped
# back behind the Sharing pane's back:
#   1. the sshd launchd job (system/com.openssh.sshd) — nix-darwin's
#      `services.openssh.enable` re-enables and bootstraps it on activation;
#   2. the service ACL group `com.apple.access_ssh`. While that group exists,
#      pam_sacl admits only its members: sshd accepts the public key, then
#      closes the connection ("Access denied for user k by PAM account
#      configuration"; the client only sees "Connection closed"). "Allow
#      access for: All users" renames the group to com.apple.access_ssh-disabled,
#      so a missing group means everyone is allowed and there is nothing to do.
#
# Observed 2026-11-16 on SOC-Kris-Williams: Remote Login turned itself off and
# the ACL group came back without k minutes after both were set by hand.
#
# Activation-time only, by design: this repairs the state on each `nrs` and
# does not run on a timer, so it never fights whatever resets it in between.
{
  flake.modules.darwin.remote-login =
    { lib, config, ... }:
    let
      cfg = config.services.remote-login;
    in
    {
      options.services.remote-login = {
        enable = lib.mkEnableOption "inbound SSH (macOS Remote Login) for the listed users";
        users = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "k" ];
          description = ''
            Users added to the `com.apple.access_ssh` service ACL group when
            macOS restricts Remote Login to specific users.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        services.openssh.enable = true;

        system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
          # --- remote-login: keep the listed users in the SSH service ACL ---
          if /usr/bin/dscl . -read /Groups/com.apple.access_ssh >/dev/null 2>&1; then
            for user in ${lib.escapeShellArgs cfg.users}; do
              if ! /usr/sbin/dseditgroup -o checkmember -m "$user" com.apple.access_ssh >/dev/null 2>&1; then
                if /usr/sbin/dseditgroup -o edit -a "$user" -t user com.apple.access_ssh; then
                  echo "remote-login: added $user to com.apple.access_ssh"
                else
                  echo "remote-login: could not add $user to com.apple.access_ssh" >&2
                fi
              fi
            done
          fi
        '';
      };
    };
}
