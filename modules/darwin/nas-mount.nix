# Auto-mount the UNAS Pro 4's Personal-Drive SMB share at login via a launchd
# user agent. See docs/unifi-dream-machine.md for how nas.home.lan (a UniFi
# "Local DNS Record", not a static DNS entry) was set up. `-N` is required —
# a launchd agent has no session to show an interactive password sheet, so it
# only works because macOS already has a matching keychain entry (confirmed
# 2026-07-09: the same entry serves both the Bonjour and DNS hostnames, since
# macOS's SMB client keys off the server's negotiated identity, not the
# literal string used to connect — see the manual's "two mechanisms" note).
#
# Stable external path: nix-darwin's own root-run activation context cannot
# codesign this (confirmed 2026-07-09 — modern macOS walls the login
# keychain's private-key material off from root entirely, even via
# `launchctl asuser`; only a process genuinely running as the user in their
# real session can use it). So signing is a deliberate manual step run
# directly by the machine's owner (see docs/unifi-dream-machine.md,
# "Manually codesigning nas-mount") against this same fixed path — never
# automated, never touching the nix store (which is read-only anyway).
# postActivation only copies the latest built script here, and only when its
# content actually changed (`cmp -s` guard), so an existing manual signature
# survives every `nrs` that doesn't touch the mount logic itself.
{
  flake.modules.darwin.nas-mount =
    { lib, config, pkgs, ... }:
    let
      cfg = config.services.nas-mount;
      home = "/Users/k";
      mountPoint = "${home}/nas";
      share = "//k@nas.home.lan/Personal-Drive";
      signedBin = "${home}/.local/state/nas-mount/nas-mount";
      # writeShellScriptBin (not writeShellScript): puts the script at
      # $out/bin/nas-mount, so only the store path's *directory* carries the
      # hash — the file launchd actually execs is plain "nas-mount", which is
      # what shows up in System Settings > Login Items instead of a
      # hash-prefixed name.
      mountScript = pkgs.writeShellScriptBin "nas-mount" ''
        set -euo pipefail
        mkdir -p "${mountPoint}"
        if ! /sbin/mount | grep -qF " on ${mountPoint} "; then
          /sbin/mount_smbfs -N "${share}" "${mountPoint}"
        fi
      '';
    in
    {
      options.services.nas-mount.enable = lib.mkEnableOption "auto-mount the UNAS Pro 4 Personal-Drive SMB share at login";
      config = lib.mkIf cfg.enable {
        # Order 1600: same slot dotfiles-stow (1500) and other user-context
        # postActivation steps use — see claude-account-selector/default.nix.
        system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
          /usr/bin/sudo -u k --set-home /bin/sh -c '
            set -e
            mkdir -p "$(dirname "${signedBin}")"
            if ! cmp -s "${mountScript}/bin/nas-mount" "${signedBin}" 2>/dev/null; then
              cp -f "${mountScript}/bin/nas-mount" "${signedBin}"
              chmod +x "${signedBin}"
            fi
          '
        '';
        launchd.user.agents.nas-mount = {
          serviceConfig = {
            ProgramArguments = [ signedBin ];
            RunAtLoad = true;
            StartInterval = 300; # retry if the NAS/network wasn't ready at login
            StandardOutPath = "${home}/Library/Logs/nas-mount.log";
            StandardErrorPath = "${home}/Library/Logs/nas-mount.log";
          };
        };
      };
    };
}
