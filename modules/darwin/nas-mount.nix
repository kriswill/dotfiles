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
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.services.nas-mount;
      home = "/Users/k";
      mountPoint = "${home}/nas";
      share = "//k@nas.home.lan/Personal-Drive";
      signedBin = "${home}/.local/state/nas-mount/nas-mount";
      # pkgs.nas-mount (pkgs/nas-mount/) — a compiled Mach-O binary, not a
      # shell script: rcodesign (scripts/sign-launchd-agents.ts) only
      # recognizes Mach-O/bundle/DMG/pkg, not plain scripts (confirmed
      # 2026-07-09 — it errors "specified path is not of a recognized type"
      # on a shell script). Its own build already puts the binary at
      # $out/bin/nas-mount, so only the store path's *directory* carries the
      # hash — what launchd execs is plain "nas-mount", which is what shows
      # up in System Settings > Login Items instead of a hash-prefixed name.
      mountBin = pkgs.nas-mount;
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
            if ! cmp -s "${mountBin}/bin/nas-mount" "${signedBin}" 2>/dev/null; then
              cp -f "${mountBin}/bin/nas-mount" "${signedBin}"
            fi
            # Unconditional, even when cmp -s skipped the copy: cp preserves
            # the nix store source'"'"'s read-only mode (no write bit for
            # anyone), and permission bits do not affect a code signature, so
            # this is safe to re-assert every activation regardless of the
            # content-diff guard above — otherwise a missing write bit can
            # get baked in forever (confirmed 2026-07-09: rcodesign/codesign
            # need to write here, and `chmod +x` alone never grants it).
            chmod u+w,+x "${signedBin}"
          '
        '';
        launchd.user.agents.nas-mount = {
          serviceConfig = {
            ProgramArguments = [
              signedBin
              mountPoint
              share
            ];
            RunAtLoad = true;
            StartInterval = 300; # retry if the NAS/network wasn't ready at login
            StandardOutPath = "${home}/Library/Logs/nas-mount.log";
            StandardErrorPath = "${home}/Library/Logs/nas-mount.log";
          };
        };
      };
    };
}
